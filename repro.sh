#!/usr/bin/env bash
set -e -u -o pipefail

SCRIPT_DIR=$(dirname $(readlink -f $BASH_SOURCE))

. /etc/os-release
case ${ID_LIKE:-${ID}} in
    rhel*)
        # # sudo dnf install gcc gcc-g++ gcc-gfortran make autoconf automake libtool pkgconf xz tar bzip2 patch
        # dnf download --source kernel
        # sudo dnf group install "Development Tools"
        KERNEL_VERSION=$(uname -r)
        KERNEL_SOURCE_DIR=/usr/src/kernels/${KERNEL_VERSION}/
        
        ;;
    debian)
        KERNEL_VERSION=$(uname -r)
        # sudo apt install build-essential curl autoconf automake libtool pkgconf tar bzip2 patch linux-headers-$(uname -r) linux-source-${KERNEL_VERSION%.*}
        # sudo apt-get build-dep linux

        KERNEL_SOURCE_DIR=$(readlink -f linux-source-${KERNEL_VERSION%.*})
        [ ! -d $KERNEL_SOURCE_DIR ] && tar xf /usr/src/linux-source-${KERNEL_VERSION%.*}.tar.xz

        ;;
esac


(
    cd $KERNEL_SOURCE_DIR
    make olddefconfig
    make prepare
)

#################################################################################################################
## mellanox version
#################################################################################################################

XPMEM_PFX=$(readlink -f xpmem_prefix)
rm -rf $XPMEM_PFX

[ ! -d xpmem ] && git clone git@github.com:tzafrir-mellanox/xpmem.git -b kmake_config
PATCH_1=$(readlink -f 63.patch)
(
    cd xpmem
    (git clean -xdff && git checkout .)
    if [ ! -f configure ]; then
        ./autogen.sh
    fi
    if [ ! -f Makefile ]; then
        ./configure --prefix=${XPMEM_PFX} \
            --with-kerneldir=$KERNEL_SOURCE_DIR --with-kernelvers=${KERNEL_VERSION%.*}
            # --with-module-prefix=/lib/modules/$(uname -r) \
    fi
    make
    make install
)
exit 0
#################################################################################################################
## HPC Vesrion - git repo
#################################################################################################################

XPMEM_PFX=$(readlink -f xpmem_prefix)
rm -rf $XPMEM_PFX

[ ! -d xpmem ] && git clone git@github.com:hpc/xpmem.git
[ ! -f 63.patch ] && curl -L -C - https://patch-diff.githubusercontent.com/raw/hpc/xpmem/pull/63.patch -o 63.patch
PATCH_1=$(readlink -f 63.patch)
(
    cd xpmem
    (git clean -xdff && git checkout .)
    git apply $PATCH_1
    if [ ! -f configure ]; then
        ./autogen.sh
    fi
    if [ ! -f Makefile ]; then
        ./configure --prefix=${XPMEM_PFX} \
            --with-kerneldir=$KERNEL_SOURCE_DIR --with-kernelvers=${KERNEL_VERSION%.*}
            # --with-module-prefix=/lib/modules/$(uname -r) \
    fi
    make
    make install
)
exit 0
#################################################################################################################
## HPC Vesrion - release
#################################################################################################################

XPMEM_SRC=$(readlink -f xpmem-2.6.3)
XPMEM_BLD=$XPMEM_SRC
XPMEM_PFX=$(readlink -f xpmem_prefix)

# [ ! -f xpmem-2.6.3.tar.gz ] && curl -L -C - https://github.com/hpc/xpmem/archive/refs/tags/v2.6.3.tar.gz -o xpmem-2.6.3.tar.gz
[ ! -f xpmem-2.6.3.tar.gz ] && curl -L -C - https://github.com/hjelmn/xpmem/archive/v2.6.3.tar.gz -o xpmem-2.6.3.tar.gz
# rm -rf $XPMEM_SRC $XPMEM_BLD $XPMEM_PFX
[ ! -d xpmem-2.6.3 ] && tar xf xpmem-2.6.3.tar.gz
[ ! -f 63.patch ] && curl -L -C - https://patch-diff.githubusercontent.com/raw/hpc/xpmem/pull/63.patch -o 63.patch

PATCH_1=$(readlink -f 63.patch)

mkdir -p $XPMEM_BLD
(
    cd $XPMEM_SRC
    git apply $PATCH_1
    if [ ! -f $XPMEM_SRC/configure ]; then
        ./autogen.sh
    fi
)

(
    cd $XPMEM_BLD
    
    if [ ! -f Makefile ]; then
        $XPMEM_SRC/configure --with-default-prefix=${XPMEM_PFX} \
            --with-kerneldir=$KERNEL_SOURCE_DIR --with-kernelvers=${KERNEL_VERSION%.*} \
            --with-module=${XPMEM_PFX}/share/modules/$(uname -r)/xpmem-2.6.3
            echo MAKE
    fi
    make V=1 VERBOSE=1
)
exit 0

#################################################################################################################
## HPE Version
#################################################################################################################

XPMEM_PFX=$(readlink -f xpmem_prefix)
rm -rf $XPMEM_PFX

[ ! -d xpmem ] && git clone git@github.com:Cray-HPE/xpmem.git
(
    cd xpmem
    (git clean -xdff && git checkout .)
    if [ ! -f configure ]; then
        ./autogen.sh
    fi
    if [ ! -f Makefile ]; then
        ./configure --prefix=${XPMEM_PFX} \
            --with-kerneldir=$KERNEL_SOURCE_DIR --with-kernelvers=${KERNEL_VERSION%.*}
            # --with-module-prefix=/lib/modules/$(uname -r) \
    fi
    make
    make install
)

# (
#     sudo rm -f /lib/modules/$(uname -r)/xpmem
#     sudo ln -s \
#         ${XPMEM_PFX}/lib/modules/5.14.0-503.40.1.el9_5/kernel/xpmem \
#         /lib/modules/$(uname -r)/xpmem
# )

# modprobe xpmem

exit 0