#!/usr/bin/env bash
set -e -u -o pipefail

SCRIPT_DIR=$(dirname $(readlink -f $BASH_SOURCE))

. /etc/os-release
case ${ID_LIKE:-${ID}} in
    debian)
        KERNEL_VERSION=$(uname -r)
        KERNEL_SOURCE_DIR=$(readlink -f linux-source-${KERNEL_VERSION})
        if [ ! -f /usr/src/linux-source-${KERNEL_VERSION%.*}.tar.xz ]; then
            sudo apt install git build-essential curl autoconf automake libtool pkgconf tar bzip2 patch linux-headers-$(uname -r) linux-source-${KERNEL_VERSION%.*}
            sudo apt-get build-dep linux
        fi
        if [ ! -d ${KERNEL_SOURCE_DIR} ]; then
            tar xf /usr/src/linux-source-${KERNEL_VERSION%.*}.tar.xz && mv linux-source-${KERNEL_VERSION%.*} ${KERNEL_SOURCE_DIR}
        fi
        ;;
    *)
        echo "ERROR: unsupported distro '${ID_LIKE:-${ID}}'"
        exit 1
        ;;
esac

[ ! -f ${KERNEL_SOURCE_DIR}/scripts/module.lds ] && (
    cd ${KERNEL_SOURCE_DIR}
    cp /boot/config-$(uname -r) .config
    make olddefconfig
    make scripts
    make prepare
    make modules_prepare
)

#################################################################################################################
## mellanox version
#################################################################################################################

XPMEM_PFX=$(readlink -f xpmem_prefix)
rm -rf $XPMEM_PFX

[ ! -d xpmem ] && git clone git@github.com:tzafrir-mellanox/xpmem.git -b kmake_config
(
    cd xpmem
    (git clean -xdff && git checkout .)
    if [ ! -f configure ]; then
        ./autogen.sh
    fi
    if [ ! -f Makefile ]; then
        ./configure --prefix=/ \
            --with-kerneldir=${KERNEL_SOURCE_DIR} --with-kernelvers=${KERNEL_VERSION}
    fi
    make
    sudo make install
    sudo depmod
    sudo modprobe xpmem
    sudo bash -c "echo xpmem > /etc/modules-load.d/xpmem.conf"
)
