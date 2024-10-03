#!/bin/bash

# Copyright (C) 2024 Embecosm Limited <www.embecosm.com>
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# Run a single benchmark program with a range of data sizes. A wrapper for
# run-one-benchmark-one-config.sh.

set -u

usage () {
    cat <<EOF
Usage ./run-one-benchmark.sh
    [--benchmark <name>]     : Name of the function to benchmark.
    [--stdlib | --no-stdlib] : Use the standard library function (default
                               --no-stdlib)
    [--verify | --no-verify] : Verify the results (default --no-verify)
    [--target-time <num>]    : Target time for any one run (default 10s)
    [--base-iter <num>]      : # iterations for size = 1 (default 1,000,000)
    [--warmup <num>]         : # iterations for warmup (default 1)
    [--sizelist <list>]      : Space separate list of sizes to use (see below)
    [--vlen <length>]        : RVV VLEN for QEMU (default 128)
    [--lmul <lmul>]          : RVV LMUL parameter (default 1)
    [--logfile <file>]       : Use this log file (default r1b.log)
    [--logdir <dir>]         : Directory for subsidiary log files (default logs)
    [--template <string>]    : Template for file names to use.
    [--csvout <file>]        : Where to put the generated CSV output
                               (default -, i.e. stdout).
    [--help]                 : Print this message and exit

The size list is 1 and then all powers of 2, 3, 5, 7 & 11 less than 100,000.

The benchmark name is just the name of the function being tested.

There is no choice of format at this stage.  Anything other than CSV is too
hard to manipulate.  If you want MarkDown or raw output, you will need to
invoke r1b-one-config.sh directly.
EOF
}

# Function to run its argument under python
runpy () {
    echo "${1}" | python
}

# Standard directories
tooldir="$(cd $(dirname $(dirname $(readlink -f $0))) ; pwd)"
topdir="$(cd $(dirname ${tooldir}) ; pwd)"
strmemdir="${tooldir}/strmem-benchmarks"
qemudir="${topdir}/qemu"
qemubuilddir="${topdir}/build/qemu"

# QEMU plugin directory varies
if [[ -e "${qemubuilddir}/tests/plugin/libinsn.so" ]]
then
    qemuplugindir="${qemubuilddir}/tests/plugin"
elif [[ -e "${qemubuilddir}/tests/tcg/plugins/libinsn.so" ]]
then
    qemuplugindir="${qemubuilddir}/tests/tcg/plugins"
else
    echo "ERROR: Cannot find QEMU plugin directory."
    exit 1
fi

export PATH="${topdir}/install/bin:${PATH}"

# Default values
benchmark="memchr"
stdlib="--no-stdlib"
verify="--no-verify"
target_time=10
base_iterations=1000000
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
logfile=""
logdir="logs"
template=""
csvout="-"

# Parse command line options
set +u
until
  opt="$1"
  case "${opt}"
  in
      --benchmark)
	  shift
	  benchmark="$1"
	  ;;
      --stdlib|--no-stdlib)
	  stdlib="$1"
	  ;;
      --verify|--no-verify)
	  verify="$1"
	  ;;
      --target-time)
          shift
	  target_time="$1"
	  ;;
      --base-iter)
          shift
	  base_iterations="$1"
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
      --template)
	  shift
	  template="$1"
	  ;;
      --csvout)
	  shift
	  csvout="$1"
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

# Create the template for files
if [[ "x${template}" == "x" ]]
then
    if [[ "x${stdlib}" == "x--stdlib" ]]
    then
	template="r1b-${benchmark}-stdlib"
    else
	template="r1b-${benchmark}-vlen-${vlen}-m${lmul}"
    fi
fi

mkdir -p ${logdir}

if [[ "x${logfile}" == "x" ]]
then
    logfile="${logdir}/${template}.log"
fi

rm -f ${logfile}
touch ${logfile}
sublog_root="${logdir}/${template}"

echo "Benchmark       : ${benchmark}"       >> ${logfile} 2>&1
echo "Standard lib    : ${stdlib}"          >> ${logfile} 2>&1
echo "Verify          : ${verify}"          >> ${logfile} 2>&1
echo "Target time     : ${target_time}"     >> ${logfile} 2>&1
echo "Base iterations : ${base_iterations}" >> ${logfile} 2>&1
echo "Warmup          : ${warmup}"          >> ${logfile} 2>&1
echo "Size list       : ${sizelist}"        >> ${logfile} 2>&1
echo "VLEN            : ${vlen}"            >> ${logfile} 2>&1
echo "LMUL            : ${lmul}"            >> ${logfile} 2>&1

# Build the benchmark executable.  This has to be in a unique location so we
# can build multiple instances.
if [[ "x${stdlib}" == "x--stdlib" ]]
then
    stdlib_flag="-DSTANDARD_LIB"
else
    stdlib_flag=
fi
if [[ "x${verify}" == "x--verify" ]]
then
    verify_flag="-DVERIF"
else
    verify_flag=
fi

extra_defs="${stdlib_flag} ${verify_flag}"
tmpexedir=$(mktemp -d r1b-src-XXXXXX)
cp -r src/* ${tmpexedir}

# We force a clean, since the source may not have changed, but the #define's
# may have done so.
if ! make -C "${tmpexedir}" clean >> ${logfile} 2>&1
then
    echo "ERROR: Failed to clean ${benchmark} benchmark in ${tmpexedir}"
    exit 1
fi

if ! make -C ${tmpexedir} LMUL=${lmul} BENCHMARK=${benchmark} \
     EXTRA_DEFS="${extra_defs}" >> ${logfile} 2>&1
then
    echo "ERROR: Failed to build ${benchmark} benchmark in ${tmpexedir}"
    exit 1
fi

# We have to work out the number of iterations to give us the target execution
# time.  We do an initial quick run to get us an estimate.  We also do a
# rebuild of the benchmark in this run.  The results are csv, so we can easily
# extract the data we need.  We can also print the header from this run
tmpcsv="$(mktemp r1b-XXXXXX.csv)"
prev_size=$(echo "${sizelist}" | sed -e 's/ *\([[:digit:]]\+\) .*$/\1/')
./run-one-benchmark-one-config.sh --benchmark ${benchmark} \
    --bmdir ${tmpexedir} ${stdlib} ${verify} --iter ${base_iterations} \
    --warmup ${warmup} --size ${prev_size} --vlen ${vlen} --lmul ${lmul} \
    --hdr --csv --logfile "${sublog_root}-${prev_size}.log" > ${tmpcsv}
if ! csvtool namedcol "Time" "${tmpcsv}" > /dev/null 2>&1
then
    echo "ERROR: Bad initial ${tmpcsv}"
    exit 1
fi
prev_t=$(csvtool namedcol "Time" "${tmpcsv}" | csvtool drop 1 -)

if [[ "x${csvout}" == "x-" ]]
then
    head -1 "${tmpcsv}"
else
    head -1 "${tmpcsv}" > ${csvout}
fi

# Run for all the sizes.  We use the timing, size and iterations of
# the previous run to estimate the iterations for this run.
iterations=${base_iterations}
for size in ${sizelist}
do
    iterations=$(runpy "f1 = ${target_time} * ${iterations} * ${prev_size}; \
                        f2 = ${prev_t} * ${size} ; \
                        i = int(f1 / f2); print (i)")
    ./run-one-benchmark-one-config.sh --benchmark ${benchmark} \
        --bmdir ${tmpexedir} ${stdlib} ${verify} --iter ${iterations} \
	--warmup ${warmup} --size ${size} --vlen ${vlen} --lmul ${lmul} \
	--hdr --csv --logfile "${sublog_root}-${size}.log" > ${tmpcsv}
    prev_size=${size}
    if ! csvtool namedcol "Time" "${tmpcsv}" > /dev/null 2>&1
    then
	if [[ "x${stdlib}" == "x--stdlib" ]]
	then
	    n="${benchmark}-stdlib"
	else
	    n="${benchmark}-${vlen}-m${lmul}"
	fi
	    echo "ERROR: ${n}: Bad ${tmpcsv} or ${tmpexedir} for size ${size}"
	exit 1
    fi
    prev_t=$(csvtool namedcol "Time" "${tmpcsv}" | csvtool drop 1 -)
if [[ "x${csvout}" == "x-" ]]
then
    tail -1 "${tmpcsv}"
else
    tail -1 "${tmpcsv}" >> ${csvout}
fi
done

rm -rf "${tmpexedir}"
rm -f "${tmpcsv}"
