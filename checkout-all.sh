#!/bin/bash

# Checkout script for the RISC-V tool chain

# Copyright (C) 2009, 2013-2017, 2022-2024 Embecosm Limited
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# This file is part of the Embecosm GNU toolchain build system for RISC-V.

# SPDX-License-Identifier: GPL-3.0-or-later

# Invocation Syntax

#     checkout-all.sh [--pull]

# Argument meanings:

#     --pull  Pull the respositories as well as checking them out.

# Parse arg

do_pull=false
qemu_checkout=""

usage () {
    cat <<EOF
Usage ./checkout-all.sh           : Checkout the tool chain and QEMU
          [--pull]                : Pull the repository after checkout
          [--qemu-checkout <tag>] : Checkout a specific version of QEMU.
          [--help]                : Print this message and exit.
EOF
}

set +u
until
  opt="$1"
  case "${opt}" in
      --pull)
	  do_pull=true
	  ;;
      --qemu-checkout)
	  shift
	  qemu_checkout="$1"
	  ;;
      --help)
	  usage
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

# Import the default branches
source EXPECTED_BRANCHES

if [ -z "${qemu_checkout}" ]
then
	qemu_checkout="${QEMU_BRANCH}"
fi

# Set the top level directory.
topdir=$(cd $(dirname $0)/..;pwd)

repos="binutils:${BINUTILS_BRANCH}                      \
       gdb:${GDB_BRANCH}                                \
       gcc:${GCC_BRANCH}                                \
       llvm-project:${LLVM_BRANCH}                      \
       glibc:${GLIBC_BRANCH}				\
       qemu:${qemu_checkout}				\
       riscv-gnu-toolchain:${TOOLCHAIN_BRANCH} "

# Some repos may be missing in a minimal checkout.  Silently ignore missing
# repos.
for r in ${repos}
do
    tool=$(echo ${r} | cut -d ':' -f 1)
    branch=$(echo ${r} | cut -d ':' -f 2)

    if [[ -d ${topdir}/${tool} ]]
    then
	cd ${topdir}/${tool}
	# Ignore failed fetches (may be offline)

	printf  "%-14s fetching...  " "${tool}:"
	git fetch --all > /dev/null 2>&1 || true

	# Checkout the branch. Not sure what happens if the branch is in
	# mutliple remotes.

	echo -n "checking out ${branch} ...  "
	git checkout ${branch} > /dev/null 2>&1 || true

	# Pull to the latest if requested.
	if ${do_pull}
	then
	    echo -n "pulling..."
	    git pull > /dev/null 2>&1 || true
	fi

	# Repo done
	echo
    fi
done
