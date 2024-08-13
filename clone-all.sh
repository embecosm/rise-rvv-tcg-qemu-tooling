#!/bin/bash

# Clone script for the RISC-V tool chain
#
# Copyright (C) 2009, 2013, 2014, 2015, 2016, 2017, 2022, 2023, 2024 Embecosm Limited
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>
#
# This file is part of the Embecosm GNU toolchain build system for RISC-V.
#
# SPDX-License-Identifier: GPL-3.0-or-later

# Invoke with:
#
#     ./clone-all.sh

# Function to print a help message
usage () {
    cat <<EOF
Usage ./clone-all.sh              : Clone the tool chain and QEMU repos
          [--all|--minimal]       : Clone all repos (defautlt minimal)
          [--qemu-url <git-url>]  : QEMU URL to clone from.
          [--help]                : Print this message and exit.

--qemu-url is particularly useful to specify a SSH repo link to faciliate
writing to the repository.
EOF
}

# Function to only clone if not already there.
# $1 URL
# $2 directory
cloneit () {
    if [[ -e "$2" ]]
    then
	echo "$2 already cloned?"
    else
	git clone $1 $2
    fi
}

# Set flags
minimal=true

# Set the top level directory.
tooldir=$(cd $(dirname $0);pwd)
topdir=$(cd $(dirname $0)/..;pwd)

# Set the URLs which hold the repos
KERNEL_URL=git://git.kernel.org/pub/scm
GCC_URL=git://gcc.gnu.org/git
LLVM_URL=https://github.com/llvm
SOURCEWARE_URL=git://sourceware.org/git
TOOLCHAIN_URL=https://github.com/riscv
QEMU_URL=https://github.com/embecosm

# Set the specific repos
binutils_repo=${SOURCEWARE_URL}/binutils-gdb.git
gdb_repo=${SOURCEWARE_URL}/binutils-gdb.git
gcc_repo=${GCC_URL}/gcc.git
llvm_repo=${LLVM_URL}/llvm-project.git
glibc_repo=${SOURCEWARE_URL}/glibc.git
linux_repo=${KERNEL_URL}/linux/kernel/git/torvalds/linux.git
qemu_repo=${QEMU_URL}/rise-rvv-tcg-qemu.git
rv_toolchain_repo=${TOOLCHAIN_URL}/riscv-gnu-toolchain.git

set +u
until
  opt="$1"
  case "${opt}" in
      --all)
	  minimal=false
	  ;;
      --minimal)
	  minimal=true
	  ;;
      --qemu-url)
	  shift
	  qemu_repo="$1"
	  ;;
      --help)
	  usage
	  exit 0
	  ;;
      ?*)
	  echo "Unknown argument '$1'"
	  usage
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

cd ${topdir}

# Toolchain repos
cloneit ${qemu_repo}         qemu
cloneit ${rv_toolchain_repo} riscv-gnu-toolchain

if ! ${minimal}
then
    cloneit ${binutils_repo}     binutils
    cloneit ${gdb_repo}          gdb
    cloneit ${gcc_repo}          gcc
    cloneit ${llvm_repo}         llvm-project
    cloneit ${glibc_repo}        glibc
    cloneit ${linux_repo}        linux
fi

# Get the right branches
cd ${tooldir}
./checkout-all.sh
