#!/bin/bash

# Script to compute SPEC CPU 2017 scores obtained by QEMU

# Copyright (C) 2023, 2024 Embecosm Limited
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# This script searches for generated instruction count (*.icount) files in the
# SPEC directory. This is converted to a time, on the basis of QEMU executing
# 10^9 instructions per second.  Usage:
#
#   calc-spec-qemu.sh [--csv|--md] [--specdir <SPEC dir>]

set -u

# Print out the help message
dohelp () {
    echo "Usage: calc-spec-qemu.sh [--csv|--md]"
    echo "                         [--speclog <log>]"
    echo "                         [--help|-h]"
}

# Set default values
topdir="$(dirname $(cd $(dirname $0) && echo ${PWD}))"
tooldir="${topdir}/rise-rvv-tcg-qemu-tooling"
installdir="${topdir}/install"
tmpfile="$(mktemp -p /tmp calc-spec-qemu-XXXXXXXX)"
pformat=""
speclog=
specdir=

# Parse command line options
set +u
until
    opt="$1"
    case "${opt}"
    in
	--csv|--md)
	    pformat="$1"
	    ;;
	--speclog)
	    shift
	    if [ ! -e "$1" ]
	    then
		echo "ERROR: non-existent SPEC log: exiting"
		exit 1
	    else
		speclog="$1"
		specdir="$(sed -n -e 's/^specdir:[[:space:]]\+\(.*\)$/\1/p' < $1)"
		if [ ! -d ${specdir} ]
		then
		    "ERROR: non-existent SPEC directory \"${specdir}\""
		    exit 1
		fi
	    fi
	    ;;
	--help|-h)
	    dohelp
	    exit 0
	    ;;
	?*)
	    echo "Unknown argument '$1'"
	    dohelp
	    exit 1
	    ;;
    esac
    [ "x${opt}" = "x" ]
do
    shift
done
set -u

if [ "x${specdir}" = "x" ]
then
    dohelp
    exit 1
fi

# Work out which base data set to use
datasize=$(grep '^size: ' ${speclog} | head -1 | sed -e 's/size:[[:space:]]\+//')

case ${datasize}
in
    test)
	basedata="${tooldir}/specbasedata-test.txt"
	;;
    ref)
	basedata="${tooldir}/specbasedata-ref.txt"
	;;
    *)
	echo "Unsupported size: ${size}"
	exit 1
	;;
esac

# Total the workloads for each benchmark
rm -f ${tmpfile}
touch ${tmpfile}
for icf in $(find ${specdir} -name '*.icount' -print)
do
    bm=$(basename ${icf} | sed -e 's/-.*//')
    ic="$(sed -n -e 's/total insns: //p' < ${icf})"
    printf "%-15s %15d\n" ${bm} ${ic} >> ${tmpfile}
 done

awk -f ${tooldir}/collate-times.awk ${pformat} ${basedata} < ${tmpfile}
rm ${tmpfile}
