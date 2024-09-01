#!/bin/bash

# Script to build the RISC-V GNU tool chain

# Copyright (C) 2009, 2013, 2014, 2015, 2016, 2017, 2022, 2023, 2024 Embecosm Limited
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# This file is part of the Embecosm GNU toolchain build system for RISC-V.

# SPDX-License-Identifier: GPL-3.0-or-later

set -u

usage () {
    cat <<EOF
Usage ./build-all.sh                      : Build riscv64-unknown-linux-gnu
                                            tool chain and QEMU (default)
                     [--build-qemu]       : Build qemu-riscv32 and qemu-riscv64
                     [--build-clang]      : Build Clang/LLVM
                     [--build-gdbserver]  : Build gdbserver
		     [--qemu-only]        : Only build qemu
		     [--qemu-configs]     : Additional QEMU config otions
		     [--qemu-cflags]      : CFLAGS for building QEMU (default
                                            "-Wno-error")
                     [--profile-qemu]     : Enable profiling by gperf
                     [--prefix <path>]    : Install path of the tool chain.
                                            Default path is ../install
                     [--arch <arch>]      : Target architecture. Default
                                            architecture is rv64gc
                     [--abi <abi>]        : Target ABI. Default ABI is lp64d
                     [--tune <tune>]      : Target tuning. Default tuning is
                                            unset
                     [--multilib-linux [scalar | vector] Type of multilib to build.
                     [--disable-multilib] : Disable multilibs
                     [--hashes]           : Print to hashes.txt the hashes of
                                            the HEAD commits of each tool in
                                            the tool chain
		     [--autoconf-version] : Version of autoconf to generate.
		     [--autoconf-temp-dir] : Build/install directory for autoconf.
                     [--clean]            : Delete build directories in
                                            riscv-gnu-toolchain and the install
                                            directory before building
                     [--clean-qemu]       : Clean just the QEMU build
                     [--help]             : Print this message and exit
EOF
}

TOPDIR="$(dirname $(cd $(dirname $0) && echo $PWD))"
actmpdir=$(mktemp -d -p /tmp build-all-ac-XXXXXX)

INSTALLDIR=${TOPDIR}/install
BUILDDIR=${TOPDIR}/build
LOGDIR=${TOPDIR}/logs

DEFAULTARCH=rv64gc
DEFAULTTUNE=
DEFAULTABI=lp64d
DEFAULTTRIPLE=riscv64-unknown-elf

build_linux=true
qemu_only=false
qemu_configs=""
qemu_cflags=""
profile_qemu=""
build_gdbserver=false
build_clang=false
clean_build=false
clean_qemu_build=false
enable_multilib=true
print_help=false
print_hashes=false
autoconf_version=""
autoconf_temp_dir=""

TARGETARCH="${DEFAULTARCH}"
TARGETTUNE="${DEFAULTTUNE}"
TARGETABI="${DEFAULTABI}"
TARGETTRIPLE="${DEFAULTTRIPLE}"

# Fixed set of permitted multilibs
SCALAR_MULTILIB_LINUX="rv32gc-ilp32d rv64gc-lp64d"
VECTOR_MULTILIB_LINUX="rv32gcv-ilp32d rv64gcv-lp64d"
SCALAR_MULTILIB_OPTIONS="march=rv32gc/march=rv64gc/ mabi=ilp32d/mabi=lp64d"
VECTOR_MULTILIB_OPTIONS="march=rv32gcv/march=rv64gcv/ mabi=ilp32d/mabi=lp64d"
SCALAR_MULTILIB_DIRNAMES="rv32gc rv64gc ilp32d lp64d"
VECTOR_MULTILIB_DIRNAMES="rv32gcv rv64gcv ilp32d lp64d"
SCALAR_MULTILIB_REQUIRED="march=rv32gc/mabi=ilp32d march=rv64gc/mabi=lp64d"
VECTOR_MULTILIB_REQUIRED="march=rv32gcv/mabi=ilp32d march=rv64gcv/mabi=lp64d"

EXTRA_OPTS=""
EXTRA_LLVM_OPTS=""
EXTRA_CFLAGS=""
MULTILIB_LINUX="${SCALAR_MULTILIB_LINUX}"
MULTILIB_OPTIONS="${SCALAR_MULTILIB_OPTIONS}"
MULTILIB_DIRNAMES="${SCALAR_MULTILIB_DIRNAMES}"
MULTILIB_REQUIRED="${SCALAR_MULTILIB_REQUIRED}"

# Parse command line options
set +u
until
  opt="$1"
  case "${opt}" in
      --prefix)
	  shift
	  INSTALLDIR="$1"
	  ;;
      --arch)
	  shift
	  TARGETARCH="$1"
	  ;;
      --tune)
	  shift
	  TARGETTUNE="$1"
	  ;;
      --abi)
	  shift
	  TARGETABI="$1"
	  ;;
      --build-elf)
	  build_linux=false
	  ;;
      --qemu-only)
	  qemu_only=true
	  ;;
      --qemu-configs)
	  shift
	  qemu_configs="$1"
	  ;;
      --qemu-cflags)
	  shift
	  qemu_cflags="$1"
	  ;;
      --profile-qemu)
	  profile_qemu="--enable-gprof"
	  ;;
      --build-gdbserver)
	  build_gdbserver=true
	  ;;
      --build-clang)
	  build_clang=true
	  ;;
      --disable-multilib)
	  enable_multilib=false
	  ;;
      --multilib-generator)
	  shift
	  MULTILIB_ELF="$1"
	  ;;
      --multilib-linux)
	  shift
	  case "x$1" in
	      scalar|Scalar|SCALAR)
		  MULTILIB_LINUX="${SCALAR_MULTILIB_LINUX}"
		  MULTILIB_OPTIONS="${SCALAR_MULTILIB_OPTIONS}"
		  MULTILIB_DIRNAMES="${SCALAR_MULTILIB_DIRNAMES}"
		  MULTILIB_REQUIRED="${SCALAR_MULTILIB_REQUIRED}"
		  ;;
	      vector|Vector|VECTOR)
		  MULTILIB_LINUX="${VECTOR_MULTILIB_LINUX}"
		  MULTILIB_OPTIONS="${VECTOR_MULTILIB_OPTIONS}"
		  MULTILIB_DIRNAMES="${VECTOR_MULTILIB_DIRNAMES}"
		  MULTILIB_REQUIRED="${VECTOR_MULTILIB_REQUIRED}"
		  ;;
	      *)
		  echo "Unknown Linux multilib type: $1"
		  ;;
	  esac
	  ;;
      --hashes)
	  print_hashes=true
	  ;;
      --autoconf-version)
	  shift
	  autoconf_version="$1"
	  ;;
      --autoconf-temp-dir)
	  shift
	  autoconf_temp_dir="$1"
	  ;;
      --clean)
	  clean_build=true
	  clean_qemu_build=true
	  ;;
      --clean-qemu)
	  clean_qemu_build=true
	  ;;
      --help)
	  print_help=true
	  ;;
      ?*)
	  echo "Unknown argument '$1'"
	  exit 1
	  ;;
      *)
	  ;;
  esac
[ "x${opt}" = "x" ]
do
  shift
done
set -u

if ${print_help}
then
    usage
    exit 1
fi

echo "Logging in:          ${LOGDIR}"
mkdir -p ${LOGDIR}

# Function to build a version of autoconf
# - $1: The version to build
# - $2: A directory in which to build and install
getautoconf () {
    if [[ "x$1" == "x" ||  "x$2" == "x" ]]
    then
        echo "Usage: $0 <version> <tmpdir>" >&2
        return 1
    fi
    v="$1"
    d="$2"
    pushd ${d}
    wget http://ftp.gnu.org/gnu/autoconf/autoconf-${v}.tar.gz
    tar xf autoconf-${v}.tar.gz
    mkdir build
    pushd build
    ../autoconf-${v}/configure --prefix="${d}/install"
    make -j
    make install
    popd
    popd
}

# Sanity check the autoconf version

if ! ${qemu_only}
then
    if ! autoconf --version | grep -q '2.69'
    then
        log_file="${LOGDIR}/build-autoconf.log"
        echo "Building autoconf 2.69...               logging to ${log_file}"
        getautoconf "2.69" ${actmpdir} > ${log_file} 2>&1
        PATH=${actmpdir}/install/bin:$PATH
    fi
fi

# Print the GCC and G++ used in this build
which gcc
which g++

if ${qemu_only}
then
    build_linux=false
    build_gdbserver=false
    build_clang=false
    enable_multilib=false
fi

echo
echo "Build plan:"
echo "  arch: ${TARGETARCH}"
echo "  tune: ${TARGETTUNE}"
echo "  abi: ${TARGETABI}"
if ${build_linux}
then
  echo "  build linux: yes"
  EXTRA_OPTS="${EXTRA_OPTS} --enable-linux"
  TARGETTRIPLE="riscv64-unknown-linux-gnu"
  if ${enable_multilib}
  then
      sed -i -r -e "s/\[AC_SUBST\(glibc_multilib_names,\"rv.*\"\)\]/\[AC_SUBST\(glibc_multilib_names,\"$MULTILIB_LINUX\"\)\]/g" $TOPDIR/riscv-gnu-toolchain/configure.ac
    cd $TOPDIR/riscv-gnu-toolchain
    autoconf
    cd - > /dev/null 2>&1
    # Hack to fix up broken multilibs
    cd ${TOPDIR}/gcc/gcc/config/riscv > /dev/null 2>&1
    mv t-linux-multilib t-linux-multilib.orig
    touch t-linux-multilib
    echo "MULTILIB_OPTIONS = ${MULTILIB_OPTIONS}" >> t-linux-multilib
    echo "MULTILIB_DIRNAMES = ${MULTILIB_DIRNAMES}" >> t-linux-multilib
    echo "MULTILIB_REQUIRED = ${MULTILIB_REQUIRED}" >> t-linux-multilib
    cd - > /dev/null 2>&1
  fi
else
  echo "  build linux: no"
fi
if ${enable_multilib}
then
  echo "  multilib: yes"
  EXTRA_OPTS="${EXTRA_OPTS} --enable-multilib"
else
  echo "  multilib: no"
  EXTRA_OPTS="${EXTRA_OPTS} --disable-multilib"
fi
echo "  build qemu: yes"
echo "   qemu_configs: ${qemu_configs}"
echo "   qemu_cflags: ${qemu_cflags}"
if ${clean_qemu_build}
then
   echo "   qemu_clean: yes"
else
   echo "   qemu_clean: no"
fi

if ${build_gdbserver}
then
  echo "  build gdbserver: yes"
else
  echo "  build gdbserver: no"
fi
if ${build_clang}
then
  echo "  build Clang: yes"
else
  echo "  build Clang: no"
fi

cd $TOPDIR/riscv-gnu-toolchain

log_file="${LOGDIR}/clean-toolchain.log"
if ${clean_build} && ! ${qemu_only}
then
  echo
  echo "Cleaning...                            logging to ${log_file}"
  # We need to configure in case we have a broken existing configuration
  (
      set -ex
      rm -f config.status
      ./configure
  ) > ${log_file} 2>&1
  if [ $? -ne 0 ]; then
      echo "Error configuring for cleaning, check log file!" >&2
      exit 1
  fi

  (
      make -j $(nproc) clean
  ) > ${log_file} 2>&1
  if [ $? -ne 0 ]; then
      echo "Error cleaning, check log file!" >&2
      exit 1
  fi

  rm -rf ${BUILDDIR}/*
  # Don't blow away SPEC installations
  rm -rf ${INSTALLDIR}/{bin,include,lib*,risc*,share,sysroot}
fi

echo
echo "Building in:         $TOPDIR/riscv-gnu-toolchain/"
echo "Installing in:       ${INSTALLDIR}"

if ! ${qemu_only}
then
    log_file="${LOGDIR}/configure-toolchain.log"
    echo "Configuring Tool Chain...              logging to ${log_file}"
    (
    #  export EXTRA_CFLAGS="${EXTRA_CFLAGS} -mavx"
      set -ex
      ./configure \
          --with-arch=$TARGETARCH --with-tune=$TARGETTUNE --with-abi=$TARGETABI \
          --prefix=$INSTALLDIR \
          --with-gcc-src=$TOPDIR/gcc \
          --with-binutils-src=$TOPDIR/binutils \
          --with-newlib-src=$TOPDIR/newlib \
          --with-glibc-src=$TOPDIR/glibc \
          --with-gdb-src=$TOPDIR/gdb \
          --with-cmodel=medany \
          ${EXTRA_OPTS}
    ) > ${log_file} 2>&1
    if [ $? -ne 0 ]; then
      echo "Error configuring, check log file!" >&2
      exit 1
    fi
fi

if ! ${qemu_only}
then
    log_file="${LOGDIR}/build-toolchain.log"
    echo "Building Tool Chain...                 logging to ${log_file}"
    (
      make -j $(nproc)
    ) > ${log_file} 2>&1
    if [ $? -ne 0 ]; then
      echo "Error building, check log file!" >&2
      exit 1
    fi
fi

# No need to configure the QEMU targets as the default ones are already
# riscv32-linux-user and riscv64-linux-user.
log_file="${LOGDIR}/build-qemu.log"
echo "Building QEMU...                 logging to ${log_file}"
(
  mkdir -p ${BUILDDIR}/qemu
  cd ${BUILDDIR}/qemu
  $TOPDIR/qemu/configure --prefix=$INSTALLDIR \
	  --target-list=riscv64-linux-user,riscv32-linux-user \
	  --interp-prefix=$INSTALLDIR/sysroot \
	  --python=python3 ${profile_qemu} \
	  ${qemu_configs} \
	  --extra-cflags="${qemu_cflags}"
  if ${clean_build} || ${clean_qemu_build}
  then
      rm -f ${INSTALLDIR}/bin/qemu-riscv??
      make clean
  fi
  make -j $(nproc)
  make install
) > ${log_file} 2>&1
if [ $? -ne 0 ]; then
  echo "Error building, check log file!" >&2
  exit 1
fi

# Clang
if ${build_clang}
then
    mkdir -p ${LOGDIR}
    log_file="${LOGDIR}/configure-clang.log"
    echo "Configuring Clang...                 logging to ${log_file}"
    (
	# Attempt to identify the host architecture, and include this in the
	# build
	if [ "$(arch)" == "arm64" ]; then
	    LLVM_NATIVE_ARCH="AArch64"
	else
	    LLVM_NATIVE_ARCH="X86"
	fi

	# Location of the binutils repository in order to pass the linker
	# plugin header to LLVM's build system
	BINUTILS_DIR="${TOPDIR}/binutils"

	# Build and install it
	set -e
	mkdir -p ${BUILDDIR}/llvm
	set -x
	cd ${BUILDDIR}/llvm
	cmake -G"Unix Makefiles"                                           \
	      -DCMAKE_BUILD_TYPE=Release                                   \
	      -DCMAKE_INSTALL_PREFIX=${INSTALLDIR}                         \
	      -DLLVM_ENABLE_PROJECTS=clang\;lld                            \
	      -DLLVM_ENABLE_PLUGINS=ON                                     \
	      -DLLVM_BINUTILS_INCDIR=${BINUTILS_DIR}/include  \
	      -DLLVM_DISTRIBUTION_COMPONENTS=clang\;clang-resource-headers\;lld\;llvm-ar\;llvm-cov\;llvm-cxxfilt\;llvm-dwp\;llvm-ranlib\;llvm-nm\;llvm-objcopy\;llvm-objdump\;llvm-readobj\;llvm-size\;llvm-strings\;llvm-strip\;llvm-profdata\;llvm-symbolizer\;LLVMgold \
	      -DLLVM_PARALLEL_LINK_JOBS=5                                  \
	      -DLLVM_TARGETS_TO_BUILD=${LLVM_NATIVE_ARCH}\;RISCV           \
	      -DDEFAULT_SYSROOT=${INSTALLDIR}/sysroot                      \
	      ${EXTRA_LLVM_OPTS}                                           \
	      ${TOPDIR}/llvm-project/llvm
    ) > ${log_file} 2>&1
    if [ $? -ne 0 ]; then
	echo "Error configuring Clang, check log file!" >&2
	exit 1
    fi

  log_file="${LOGDIR}/build-clang.log"
  echo "Building Clang...                 logging to ${log_file}"
  (
      cd ${BUILDDIR}/llvm
      make -j$(nproc)
      make install-distribution

      # Add symlinks to LLVM tools
      cd ${INSTALLDIR}/bin
      for TOOL in clang clang++; do
	  ln -sv clang riscv64-unknown-linux-gnu-${TOOL}
      done
  ) > ${log_file} 2>&1
  if [ $? -ne 0 ]; then
      echo "Error building Clang, check log file!" >&2
      exit 1
  fi
fi

PATH=${INSTALLDIR}/bin:$PATH

if ${build_gdbserver}
then
  log_file="${LOGDIR}/configure-gdbserver.log"
  echo "Configuring gdbserver...                 logging to ${log_file}"
  (
    set -e
    mkdir -p ${BUILDDIR}/gdbserver
    set -x
    cd ${BUILDDIR}/gdbserver
    ../../gdb/configure \
        CC="${TARGETTRIPLE}-gcc -static" \
        CXX="${TARGETTRIPLE}-g++ -static" \
        --prefix=${INSTALLDIR} \
        --cache-file=/dev/null \
        --disable-bfd \
        --disable-binutils \
        --disable-gas \
        --disable-gdb \
        --disable-gold \
        --disable-gprof \
        --disable-ld \
        --disable-libctf \
        --disable-libdecnumber \
        --disable-opcodes \
        --disable-readline \
        --disable-sim \
        --host=${TARGETTRIPLE} \
        ${EXTRA_OPTS}
  ) > ${log_file} 2>&1
  if [ $? -ne 0 ]; then
    echo "Error configuring gdbserver, check log file!" >&2
    exit 1
  fi

  log_file="${LOGDIR}/build-gdbserver.log"
  echo "Building gdbserver...                 logging to ${log_file}"
  (
    cd ${BUILDDIR}/gdbserver
    make -j $(nproc)
    make install
  ) > ${log_file} 2>&1
  if [ $? -ne 0 ]; then
    echo "Error building gdbserver, check log file!" >&2
    exit 1
  fi
fi

if $print_hashes
then
  hashes_file="$TOPDIR/hashes.txt"
  echo "Printing hashes to $hashes_file"
  cd $TOPDIR/binutils
  BINUTILS_HASH=$(git rev-parse HEAD)
  cd $TOPDIR/gdb
  GDB_HASH=$(git rev-parse HEAD)
  cd $TOPDIR/gcc
  GCC_HASH=$(git rev-parse HEAD)
  cd $TOPDIR/newlib
  NEWLIB_HASH=$(git rev-parse HEAD)
  cd $TOPDIR/glibc
  GLIBC_HASH=$(git rev-parse HEAD)

  cd $TOPDIR
  echo "binutils: $BINUTILS_HASH" >> ${hashes_file}
  echo "gdb: $GDB_HASH" >> ${hashes_file}
  echo "gcc: $GCC_HASH" >> ${hashes_file}
  echo "newlib: $NEWLIB_HASH" >> ${hashes_file}
  echo "glibc: $GLIBC_HASH" >> ${hashes_file}
fi

echo "Cleaning up"

pushd $TOPDIR/riscv-gnu-toolchain > /dev/null 2>&1
if ! git checkout configure configure.ac > /dev/null 2>&1
then
    echo "Unable to restore configure and configure.ac in riscv-gnu-toolchain"
    echo "- manual restoration recommended."
fi
popd > /dev/null 2>&1

cd ${TOPDIR}/gcc/gcc/config/riscv > /dev/null 2>&1
if [[ -e t-linux-multilib.orig ]]
then
    rm -f t-linux-multilib
    mv t-linux-multilib.orig t-linux-multilib
fi
cd - > /dev/null 2>&1

rm -rf ${actmpdir}

echo "Build completed successfully."
