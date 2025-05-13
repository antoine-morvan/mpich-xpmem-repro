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


XPMEM_SRC=$(readlink -f xpmem-2.6.3)
XPMEM_BLD=$XPMEM_SRC
XPMEM_PFX=$(readlink -f xpmem_prefix)

# [ ! -f xpmem-2.6.3.tar.gz ] && curl -L -C - https://github.com/hpc/xpmem/archive/refs/tags/v2.6.3.tar.gz -o xpmem-2.6.3.tar.gz
[ ! -f xpmem-2.6.3.tar.gz ] && curl -L -C - https://github.com/hjelmn/xpmem/archive/v2.6.3.tar.gz -o xpmem-2.6.3.tar.gz
# rm -rf $XPMEM_SRC $XPMEM_BLD $XPMEM_PFX
[ ! -d xpmem-2.6.3 ] && tar xf xpmem-2.6.3.tar.gz
mkdir -p $XPMEM_BLD
(
    cd $XPMEM_SRC
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