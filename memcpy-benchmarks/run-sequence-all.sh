#!/bin/bash

# Copyright (C) 2024 Embecosm Limited <www.embecosm.com>
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# A script to do multiple sequence runs

tooldir="$(cd $(dirname $(dirname $(readlink -f $0))) ; pwd)"
topdir="$(cd $(dirname ${tooldir}) ; pwd)"
memcpydir="${tooldir}/memcpy-benchmarks"
qemudir=${topdir}/qemu

logfile=${memcpydir}/run-all.log
rm -f ${logfile}
touch ${logfile}

# Baseline, prev best, new best
ids="7bbadc60b58b742494555f06cd342311ddab9351 \
     ef9e258b94376c5017b4df9fe061abcadc9661f2 \
     7809b7fafbc24c557751a1845bb1ccc0b9376f90"

export PATH=${topdir}/install/bin:${PATH}
which qemu-riscv64 2>&1 | tee -a ${logfile}

# Build all the programs to benchmark
cd ${memcpydir}
make 2>&1 | tee -a ${logfile}

# Now do the profiling
for c in ${ids}
do
    csvfile="${memcpydir}/seq-results-${c}.csv"
    echo "Checking out QEMU commit ${c}..." 2>&1 | tee -a ${logfile}
    date 2>&1 | tee -a ${logfile}
    pushd ${qemudir} > /dev/null 2>&1
    git checkout ${c} >> ${logfile} 2>&1
    popd > /dev/null 2>&1

    echo "Building QEMU for commit ${c}..." 2>&1 | tee -a ${logfile}
    date 2>&1 | tee -a ${logfile}
    pushd ${tooldir} > /dev/null 2>&1
    ./build-all.sh --qemu-only --clean-qemu >> ${logfile} 2>&1
    popd > /dev/null 2>&1

    echo "Running sequence for commit ${c}..." 2>&1 | tee -a ${logfile}
    date 2>&1 | tee -a ${logfile}
    pushd ${memcpydir} > /dev/null 2>&1
    ./run-sequence.sh --iter "100000000" --csv  > ${csvfile} 2>&1
    echo "Results in ${csvfile}" | tee -a ${logfile}
    date 2>&1 | tee -a ${logfile}
done
