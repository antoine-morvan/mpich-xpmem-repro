#!/usr/bin/env bash
set -e -u -o pipefail

SCRIPT_DIR=$(dirname $(readlink -f $BASH_SOURCE))


# sudo dnf install gcc gcc-g++ gcc-gfortran make autoconf automake libtool


XPMEM_SRC=$(readlink -f xpmem-2.6.3)
XPMEM_BLD=$(readlink -f xpmem_build)
XPMEM_PFX=$(readlink -f xpmem_prefix)

# [ ! -f xpmem-2.6.3.tar.gz ] && curl -L -C - https://github.com/hpc/xpmem/archive/refs/tags/v2.6.3.tar.gz -o xpmem-2.6.3.tar.gz
[ ! -f xpmem-2.6.3.tar.gz ] && curl -L -C - https://github.com/hjelmn/xpmem/archive/v2.6.3.tar.gz -o xpmem-2.6.3.tar.gz
rm -rf $XPMEM_SRC $XPMEM_BLD $XPMEM_PFX
[ ! -d xpmem-2.6.3 ] && tar xf xpmem-2.6.3.tar.gz
mkdir $XPMEM_BLD
(
    cd $XPMEM_SRC
    [ ! -f configure ] && ./autogen.sh
)
(
    cd $XPMEM_BLD
    $XPMEM_SRC/configure --with-default-prefix=${XPMEM_PFX} --with-module=${XPMEM_PFX}/share/modules/$(uname -r)/xpmem-2.6.3
    make
)
