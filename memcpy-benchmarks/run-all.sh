#!/bin/bash

# Copyright (C) 2024 Embecosm Limited <www.embecosm.com>
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# A script to do multiple performance profiling runs

tooldir="$(cd $(dirname $(dirname $(readlink -f $0))) ; pwd)"
topdir="$(cd $(dirname ${tooldir}) ; pwd)"
memcpydir="${tooldir}/memcpy-benchmarks"
qemudir=${topdir}/qemu

logfile=${memcpydir}/run-all.log
rm -f ${logfile}
touch ${logfile}

ids="ef9e258b94376c5017b4df9fe061abcadc9661f2 \
     7809b7fafbc24c557751a1845bb1ccc0b9376f90"

export PATH=${topdir}/install/bin:${PATH}
which qemu-riscv64 2>&1 | tee -a ${logfile}

# Build all the programs to benchmark
cd ${memcpydir}
make

# Now do the profiling
for c in ${ids}
do
    resfile="${memcpydir}/results-${c}"
    echo "Checking out QEMU commit ${c}..." 2>&1 | tee -a ${logfile}
    date 2>&1 | tee -a ${logfile}
    pushd ${qemudir} > /dev/null 2>&1
    git checkout ${c} 2>&1 | tee -a ${logfile}
    popd > /dev/null 2>&1

    echo "Building QEMU for commit ${c}..." 2>&1 | tee -a ${logfile}
    date 2>&1 | tee -a ${logfile}
    pushd ${tooldir} > /dev/null 2>&1
    ./build-all.sh --qemu-only --clean-qemu --qemu-cflags "-g" \
		   --qemu-configs "--disable-plugins" 2>&1 | tee -a ${logfile}
    popd > /dev/null 2>&1

    echo "Running perf for commit ${c}..." 2>&1 | tee -a ${logfile}
    date 2>&1 | tee -a ${logfile}
    pushd ${memcpydir} > /dev/null 2>&1
    mkdir -p "${resfile}"
    ./run-perf.sh 2>&1 | tee -a ${logfile}

    echo "Putting results in ${resfile}..." 2>&1 | tee -a ${logfile}
    mv prof-*.res "${resfile}"
    date 2>&1 | tee -a ${logfile}
    popd > /dev/null 2>&1
done
