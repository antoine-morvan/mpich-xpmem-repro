#!/usr/bin/env bash
set -e -u -o pipefail

SCRIPT_DIR=$(dirname $(readlink -f $BASH_SOURCE))

#################################################################################################################
## Install XPMEM
#################################################################################################################

if ! lsmod | grep xpmem &> /dev/null; then
    #######################################
    ## Prepare Kernel Source
    #######################################

    . /etc/os-release
    case ${ID_LIKE:-${ID}} in
        debian)
            KERNEL_VERSION=$(uname -r)
            KERNEL_SOURCE_DIR=$(readlink -f linux-source-${KERNEL_VERSION})
            if [ ! -f /usr/src/linux-source-${KERNEL_VERSION%.*}.tar.xz ]; then
                sudo apt install git build-essential gfortran curl autoconf automake libtool pkgconf tar bzip2 patch linux-headers-$(uname -r) linux-source-${KERNEL_VERSION%.*}
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

    #######################################
    ## Build / Install / Load XPMEM
    #######################################

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
            ./configure --prefix=/usr \
                --with-kerneldir=${KERNEL_SOURCE_DIR} --with-kernelvers=${KERNEL_VERSION}
        fi
        make
        sudo make install
        sudo depmod
        sudo modprobe xpmem
        sudo bash -c "echo xpmem > /etc/modules-load.d/xpmem.conf"
    )
fi

#################################################################################################################
## Install MPICH
#################################################################################################################

#######################################
## Build / Install
#######################################

MPICH_VERSION=4.3.0
MPICH_FOLDER=mpich-${MPICH_VERSION}
MPICH_ARCHIVE=${MPICH_FOLDER}.tar.gz
MPICH_URL=https://www.mpich.org/static/downloads/${MPICH_VERSION}/${MPICH_ARCHIVE}
MPICH_CACHE=$(readlink -f ${MPICH_ARCHIVE})
MPICH_PREFIX_DIR=$(readlink -f mpich_prefix)

[ ! -f ${MPICH_CACHE} ] \
    && echo "Download ${MPICH_CACHE}" \
    && curl -L -C - ${MPICH_URL} -o ${MPICH_CACHE} \
    || (echo "## --   >> Skip download '${MPICH_CACHE}'")

if [ ! -f ${MPICH_PREFIX_DIR}/lib/libmpi.so ]; then
    [ ! -d ${MPICH_FOLDER} ] \
        && echo "Extract ${MPICH_ARCHIVE}" \
        && tar xf ${MPICH_CACHE}
    (
        cd ${MPICH_FOLDER}
        if [ ! -f Makefile ]; then
            ./configure \
                --prefix=${MPICH_PREFIX_DIR} \
                --libdir=${MPICH_PREFIX_DIR}/lib \
                --enable-shared --disable-static \
                --enable-fortran \
                --enable-g=none \
                --disable-cxx \
                --disable-doc \
                --disable-maintainer-mode \
                --disable-fast \
                --with-xpmem
        fi
        make -j 8
        make install
    )
else 
    echo "## --  >> Skip mpich build"
fi

#######################################
## Configure env
#######################################

export MPICC=mpicc
export MPICXX=mpicxx
export MPIFC=mpifort

export MPICH_CC=gcc
export MPICH_CXX=g++
export MPICH_FC=gfortran
export MPICH_F90=$MPICH_FC
export MPICH_F77=$MPICH_FC

export MPI_ROOT=${MPICH_PREFIX_DIR}
export MPI_HOME=${MPI_ROOT}
export MPI_DIR=${MPI_ROOT}

export MPI_BIN=${MPI_ROOT}/bin
export MPI_LIB=${MPI_ROOT}/lib
export MPI_INC=${MPI_ROOT}/include

export PATH=${MPI_BIN}:${PATH}
export LD_LIBRARY_PATH=${MPI_LIB}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
export LIBRARY_PATH=${MPI_LIB}${LIBRARY_PATH:+:${LIBRARY_PATH}}
export PKG_CONFIG_PATH=${MPI_LIB}/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}
export C_INCLUDE_PATH=${MPI_INC}${C_INCLUDE_PATH:+:${C_INCLUDE_PATH}}

#################################################################################################################
## Install OSU Benchmark
#################################################################################################################

SETUP_VERSION=7.5
OSU_FOLDER=osu-micro-benchmarks-${SETUP_VERSION}
OSU_ARCHIVE=${OSU_FOLDER}.tar.gz
OSU_URL=https://mvapich.cse.ohio-state.edu/download/mvapich/${OSU_ARCHIVE}
OSU_CACHE=$(readlink -f ${OSU_ARCHIVE})
OSU_PREFIX_DIR=$(readlink -f osu_prefix)

[ ! -f ${OSU_CACHE} ] \
    && echo "Download ${OSU_CACHE}" \
    && curl -L -C - ${OSU_URL} -o ${OSU_CACHE} \
    || (echo "## --   >> Skip download '${OSU_ARCHIVE}'")

if [ ! -f ${OSU_PREFIX_DIR}/bin/osu_alltoallv ]; then
    [ ! -d ${OSU_FOLDER} ] \
        && echo "Extract ${OSU_ARCHIVE}" \
        && tar xf ${OSU_CACHE}
    echo "## --  >> Build osu"
    (
        cd $OSU_FOLDER
        ./configure \
                CC=$MPICC CXX=$MPICXX \
            --prefix=${OSU_PREFIX_DIR} \
            --disable-mpi4
            
        make -j 8
        mkdir -p ${OSU_PREFIX_DIR}/bin
        make install
        for e in $(find ${OSU_PREFIX_DIR}/libexec/osu-micro-benchmarks/mpi -executable); do
            name=$(basename $e)
            fullpath=$(readlink -f $e)
            ln -s $fullpath ${OSU_PREFIX_DIR}/bin/$name
        done
    )
else 
    echo "## --  >> Skip osu"
fi

export PATH=${OSU_PREFIX_DIR}/bin:${PATH}

#################################################################################################################
## Run Test
#################################################################################################################

ldd $(type -f -p osu_alltoallv)


echo -n "##  >>>>> OSU Alltoall Latency 32B: "
mpiexec -n 12 \
    osu_alltoallv -m 32:32 -i 1000000 -x 2000
