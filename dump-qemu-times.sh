#!/bin/bash

# Script to dump SPEC CPU 2017 QEMU execution times

# Copyright (C) 2023 Embecosm Limited
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# This script searches a SPEC CPU 2017 log script for records of the execution
# times of QEMU for each benchmark workload run.

set -u

# Print out the help message
dohelp () {
    cat <<EOF
Usage: dump-qemu-times.sh [--csv|--md]
                          --speclog: <dir>
                          [--verbose | --quiet]
                          [--help|-h]
EOF
}

# Set default values
topdir="$(dirname $(cd $(dirname $0) && echo ${PWD}))"
tooldir="${topdir}/rise-rvv-tcg-qemu-tooling"
installdir="${topdir}/install"
basedata="${tooldir}/spec-basedata.txt"
specdir="${installdir}/spec"
pformat="--txt"
speclog=""
verbose="--quiet"

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
	    if [ ! -e $1 ]
	    then
		echo "ERROR: non-existent SPEC log file: exiting"
		exit 1
	    else
		speclog="$1"
	    fi
	    ;;
	--verbose|--quiet)
	    verbose="$1"
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

awk -f ${tooldir}/collate-qemu-times.awk ${pformat} ${verbose} < ${speclog}
