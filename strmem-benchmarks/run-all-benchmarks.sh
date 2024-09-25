#!/bin/bash

# Copyright (C) 2024 Embecosm Limited <www.embecosm.com>
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# Run a multiple benchmark programs with a range of data sizes for multiple
# different QEMU releases. A wrapper for run-one-benchmark-many-qemu.sh

set -u

usage () {
    cat <<EOF
Usage ./run-all-benchmarks.sh
    [--bmlist <name>]        : List of benchmarks and base iterations to run
                               (see below)
    [--verify | --no-verify] : Verify the results (default --no-verify)
    [--qemulist <list>]      : List of QEMU commits to test (see below)
    [--target-time <num>]    : Target time for any one run (default 10s)
    [--warmup <num>]         : # iterations for warmup (default 1)
    [--sizelist <list>]      : Space separated list of sizes to use (see below)
    [--conflist <list>]      : Space separated list of RVV VLEN-LMUL pairs to
                               use (default "stdlib 128-1 1024-8")
    [--logfile <file>]       : Use this log file (default
                               run-one-all-benchmarks-<datestamp>.log, where
                               <datestamp> is the time the run was started).
    [--logdir <dir>]         : Directory for subsidiary log files (default logs)
    [--report | --no-report] : Report the results, comparing the first two QEMU
                               commits in qemulist grpahically. Default report.
    [--resdir <dir>]         : Results directory (default results-<datestamp>,
                               where <datestamp> is the time the run was
                               started).
    [--help]                 : Print this message and exit

The default benchmark and iterations is a list of tuples, with an initial
iteration (for the first size in the list) set for each benchmark (guess for
around 1s of execution).  The default list is:

  memchr-300000
  memcmp-8000000
  memcpy-10000000
  memmove-10000000
  memset-12000000
  strcat-1000000
  strchr-1000000
  strcmp-1000000
  strcpy-1000000
  strlen-1000000
  strncat-1000000
  strncmp-1000000
  strncpy-1000000
  strnlen-1000000

The default size list is 1 and then all powers of 2, 3, 5, 7 & 11 less than
100,000.

The default QEMU commits are the standard library (i.e. no RVV), the last
commit before the start of the project (#a0c325c4b0) and the latest RISE QEMU
project commit at the time of writing this script (#7809b7fafb).
EOF
}

# Time when we start, including a format for reporting
run_date="$(date '+%Y-%m-%d-%H-%M-%S')"
run_date_pretty="$(date '+%Y-%m-%d %H:%M:%S')"

# Standard directories
tooldir="$(cd $(dirname $(dirname $(readlink -f $0))) ; pwd)"
topdir="$(cd $(dirname ${tooldir}) ; pwd)"
strmemdir="${tooldir}/strmem-benchmarks"
qemudir="${topdir}/qemu"
qemubuilddir="${topdir}/build/qemu"

export PATH="${topdir}/install/bin:${PATH}"

# Default values
bmlist="memchr-300000      \
        memcmp-8000000     \
        memcpy-10000000    \
        memmove-10000000   \
        memset-12000000    \
        strcat-1000000     \
        strchr-1000000     \
        strcmp-1000000     \
        strcpy-1000000     \
        strlen-1000000     \
        strncat-1000000    \
        strncmp-1000000    \
        strncpy-1000000    \
        strnlen-1000000"
verify="--no-verify"
qemulist="a0c325c4b0 \
          7809b7fafb"
conflist="stdlib 128-1 1024-8"
target_time=10
warmup=1
sizelist="   1 \
             2 \
             3 \
             4 \
             5 \
             7 \
             8 \
             9 \
            11 \
            16 \
            25 \
            27 \
            32 \
            49 \
            64 \
            81 \
           121 \
           125 \
           128 \
           243 \
           256 \
           343 \
           512 \
           625 \
           729 \
          1024 \
          1331 \
          2048 \
          2401 \
          3125 \
          4096 \
          6561 \
          8192 \
         14641 \
         15625 \
         16384 \
         16807 \
         19683 \
         32768 \
         59049 \
         65536 \
         78125"

vlen=128
lmul=1
logfile=
logdir="${strmemdir}/logs"
doplot=true
resdir="${strmemdir}/results-${run_date}"

# Parse command line options
set +u
until
  opt="$1"
  case "${opt}"
  in
      --bmlist)
	  shift
	  bmlist="$1"
	  ;;
      --verify|--no-verify)
	  verify="$1"
	  ;;
      --qemulist)
	  shift
	  qemulist="$1"
	  ;;
      --conflist)
	  shift
	  conflist="$1"
	  ;;
      --target-time)
          shift
	  target_time="$1"
	  ;;
      --warmup)
          shift
	  warmup="$1"
	  ;;
      --sizelist)
          shift
	  sizelist="$1"
	  ;;
      --vlen)
          shift
	  vlen="$1"
	  ;;
      --lmul)
          shift
	  lmul="$1"
	  ;;
      --logfile)
	  shift
	  logfile="$(readlink -f $1)"
	  ;;
      --logdir)
	  shift
	  logdir="$(readlink -f $1)"
	  ;;
      --plot)
	  doplot=true
	  ;;
      --no-plot)
	  doplot=false
	  ;;
      --resdir)
	  shift
	  resdir="$(readlink -f $1)"
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

mkdir -p ${logdir}

if [[ "x${logfile}" == "x" ]]
then
    logfile="${logdir}/rab-${run_date}.log"
fi

rm -f ${logfile}
touch ${logfile}

echo "Run date        : ${run_date}"        >> ${logfile} 2>&1
echo "Benchmark list  : ${bmlist}"          >> ${logfile} 2>&1
echo "Verify          : ${verify}"          >> ${logfile} 2>&1
echo "QEMU list       : ${qemulist}"        >> ${logfile} 2>&1
echo "Target time     : ${target_time}"     >> ${logfile} 2>&1
echo "Warmup          : ${warmup}"          >> ${logfile} 2>&1
echo "Size list       : ${sizelist}"        >> ${logfile} 2>&1
echo "Conf list       : ${conflist}"        >> ${logfile} 2>&1

# Do each commit in turn
for c in ${qemulist}
do
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

    # QEMU plugin directory varies
    if [[ -e "${qemubuilddir}/tests/plugin/libinsn.so" ]]
    then
	qemuplugindir="${qemubuilddir}/tests/plugin"
    elif [[ -e "${qemubuilddir}/tests/tcg/plugins/libinsn.so" ]]
    then
	qemuplugindir="${qemubuilddir}/tests/tcg/plugins"
    else
	echo "ERROR: Cannot find QEMU plugin directory for commit ${c}."
	exit 1
    fi

    # Start each benchmark in turn
    pidlist=
    for bmbi in ${bmlist}
    do
	benchmark=$(echo "${bmbi}" | sed -e 's/-.*$//')
	base_iterations=$(echo "${bmbi}" | sed -e 's/^.*-//')
	template_prefix="r1b-res-${c}-${benchmark}"
	echo "Running ${benchmark} with base iterations ${base_iterations}"
	# Run each configuration
	for conf in ${conflist}
	do
	    if [[ "${conf}" == "stdlib" ]]
	    then
		vlen=128
		lmul=1
		runtype="stdlib"
		template="${template_prefix}-stdlib"
		stdlib="--stdlib"
	    else
		vlen="$(echo ${conf} | sed -e 's/-.*$//')"
		lmul="$(echo ${conf} | sed -e 's/^.*-//')"
		runtype="VLEN=${vlen} LMUL=${lmul}"
		template="${template_prefix}-vlen-${vlen}-m${lmul}"
		stdlib=
	    fi
	    echo "Starting ${benchmark} ${runtype} for ${c}..."
	    ./run-one-benchmark.sh --benchmark ${benchmark} ${stdlib} \
		${verify} --base-iter ${base_iterations} \
		--target-time "${target_time}" --warmup ${warmup} \
		--vlen ${vlen} --lmul ${lmul} --sizelist "${sizelist}" \
		--template "${template}" --csvout ${template}.csv & pid=$!
	    pidlist="${pidlist} ${pid}"
	done
    done

    # Wait for all the benchmarks to finish
    echo "PID list: ${pidlist}"
    cnt=10
    np="$(ps -p ${pidlist} | wc -l)"
    while [[ ${np} -gt 1 ]]
    do
	if [[ ${cnt} -eq 10 ]]
	then
	    echo -n '.'
	    cnt=1
	else
	    cnt="$(( cnt + 1 ))"
	fi
	sleep 1
	np="$(ps -p ${pidlist} | wc -l)"
    done
    echo
done

# Do a plot if requested
if ${doplot}
then
    oldqemu=$(echo "${qemulist}" | awk '{print $1}')
    newqemu=$(echo "${qemulist}" | awk '{print $2}')

    if [[ "x${oldqemu}" = "x" ]] || [[ "x${newqemu}" = "x" ]]
    then
	echo "Insufficient QEMU versions to plot"
    fi

    # Make the front page
    tmpmd=$(mktemp rab-XXXXXX.md)
    tmppdf=$(mktemp rab-XXXXXX.pdf)
    touch "${tmpmd}"
    user="$(id -un)"

    # Generic header stuff
    cat < report-header.md >> ${tmpmd}

    echo "- Datestamp: ${run_date_pretty}" >> ${tmpmd}
    echo "- User: ${user}" >> ${tmpmd}
    echo >> ${tmpmd}
    echo "## Functions benchmarked" >> ${tmpmd}
    for bmbi in ${bmlist}
    do
	benchmark=$(echo "${bmbi}" | sed -e 's/-.*$//')
	echo "- ${benchmark}" >> ${tmpmd}
    done
    echo >> ${tmpmd}
    echo "## QEMU versions" >> ${tmpmd}
    echo "- Baseline version: #${oldqemu}" >> ${tmpmd}
    echo "- Latest version:   #${newqemu}" >> ${tmpmd}
    echo >> ${tmpmd}
    echo "## Toolchain configuration" >> ${tmpmd}
    echo "GCC configuration" >> ${tmpmd}
    echo '```' >> ${tmpmd}
    riscv64-unknown-linux-gnu-gcc -v 2>&1 \
	| fold -w 105 >> ${tmpmd}
    echo '```' >> ${tmpmd}
    echo "Assembler version" >> ${tmpmd}
    echo '```' >> ${tmpmd}
    riscv64-unknown-linux-gnu-as -v </dev/null  2>&1 \
	| fold -w 105 >> ${tmpmd}
    echo '```' >> ${tmpmd}
    echo "Linker version" >> ${tmpmd}
    echo '```' >> ${tmpmd}
    riscv64-unknown-linux-gnu-ld -v  2>&1 \
	| fold -w 105 >> ${tmpmd}
    echo '```' >> ${tmpmd}
    echo "Glibc version" >> ${tmpmd}
    echo '```' >> ${tmpmd}
    ${topdir}/install/sysroot/usr/bin/ldd --version -v  2>&1 | \
	fold -w 105 >> ${tmpmd}
    echo '```' >> ${tmpmd}
    # Generated US letter landscape
    pandoc -s -V geometry:landscape ${tmpmd} -o ${tmppdf}

    # Graph each benchmark in turn
    pagelist="${tmppdf}"
    for bmbi in ${bmlist}
    do
	benchmark=$(echo "${bmbi}" | sed -e 's/-.*$//')
	oldprefix="r1b-res-${oldqemu}-${benchmark}"
	newprefix="r1b-res-${newqemu}-${benchmark}"
	./plot-one-benchmark.sh --benchmark "${benchmark}" \
	  --old-qemu "old (#${oldqemu}))" --new-qemu "latest (#${newqemu})" \
          --old-scalar-data "${oldprefix}-stdlib.csv" \
	  --new-scalar-data "${newprefix}-stdlib.csv" \
	  --old-small-vector-data "${oldprefix}-vlen-128-m1.csv" \
	  --new-small-vector-data "${newprefix}-vlen-128-m1.csv" \
	  --old-large-vector-data "${oldprefix}-vlen-1024-m8.csv" \
	  --new-large-vector-data "${newprefix}-vlen-1024-m8.csv" \
	  > /dev/null 2>&1
	pagelist="${pagelist} ${benchmark}.pdf"
    done

    # Create the final report
    gs -dNOPAUSE -sDEVICE=pdfwrite -dBATCH \
       -sOUTPUTFILE="report-${run_date}.pdf" ${pagelist} > /dev/null 2>&1
    echo "Report in report-${run_date}.pdf"
fi

# Clean up
rm -f "${tmpmd}" "${tmppdf}"

# Save the results
mkdir -p "${resdir}"
mv r1b-res-*.csv *.pdf ${resdir}
echo "Results in ${resdir}"
