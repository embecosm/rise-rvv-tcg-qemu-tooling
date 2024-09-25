#!/bin/bash

# Copyright (C) 2024 Embecosm Limited <www.embecosm.com>
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# Run a single benchmark program with a single configuration

set -u

# Function to give help
usage () {
    cat <<EOF
Usage ./run-one-benchmark-one-config.sh
    [--benchmark <name>]       : Name of the function to benchmark.
    [--bmdir <dir>]            : Directory where benchmark is built (default
                                 src)
    [--stdlib | --no-stdlib]   : Use the standard library function (default
                                 --no-stdlib)
    [--verify | --no-verify]   : Verify the results (default --no-verify)
    [--rebuild | --no-rebuild] : Rebuild the test program (default --rebuild)
    [--iter <num>]             : # iterations of the tests (default 1,000,000)
    [--warmup <num>]           : # iterations for warmup (default 1)
    [--size <num>]             : "Size" of the test (meaning is test dependent,
                                 default 1)
    [--vlen <length>]          : RVV VLEN for QEMU (default 128)
    [--lmul <lmul>]            : RVV LMUL parameter (default 1)
    [--raw | --csv | --md]     : Format of output (default raw)
    [--hdr | --no-hdr ]        : Print a header for the output (default
                                 --no-hdr)
    [--logfile <file> ]        : Use this log file (default
                                 run-one-benchmark-one-config.log)
    [--help]                   : Print this message and exit

The benchmark name is just the name of the function being tested.
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
bmdir="${strmemdir}/src"
stdlib="NO"
verify=false
rebuild=true
iterations=1000000
warmup=1
size=1
vlen=128
lmul=1
format="--raw"
header=false
logfile="run-one-benchmark-one-config.log"

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
      --bmdir)
	  shift
	  bmdir="$1"
	  ;;
      --stdlib)
	  stdlib="YES"
	  ;;
      --no-stdlib)
	  stdlib="NO"
	  ;;
      --verify)
	  verify=true
	  ;;
      --no-verify)
	  verify=false
	  ;;
      --no-rebuild)
	  rebuild=false
	  ;;
      --iter)
          shift
	  iterations="$1"
	  ;;
      --warmup)
          shift
	  warmup="$1"
	  ;;
      --size)
          shift
	  size="$1"
	  ;;
      --vlen)
          shift
	  vlen="$1"
	  ;;
      --lmul)
          shift
	  lmul="$1"
	  ;;
      --raw|--md|--csv)
	  format="$1"
	  ;;
      --hdr)
	  header=true
	  ;;
      --no-hdr)
	  header=false
	  ;;
      --logfile)
	  shift
	  logfile="$(readlink -f $1)"
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

rm -f ${logfile}
touch ${logfile}

tot_iters=$((iterations + warmup))

echo "Benchmark     : ${benchmark}"  >> ${logfile} 2>&1
echo "Benchmark dir : ${bmdir}"      >> ${logfile} 2>&1
echo "stdlib        : ${stdlib}"     >> ${logfile} 2>&1
if ${verify}
then
    echo "Verify       : TRUE"       >> ${logfile} 2>&1
else
    echo "Verify       : FALSE"      >> ${logfile} 2>&1
fi
echo "Iterations    : ${iterations}" >> ${logfile} 2>&1
echo "Warmup        : ${warmup}"     >> ${logfile} 2>&1
echo "Size          : ${size}"       >> ${logfile} 2>&1
echo "VLEN          : ${vlen}"       >> ${logfile} 2>&1
echo "LMUL          : ${lmul}"       >> ${logfile} 2>&1
echo "Output format : ${format}"     >> ${logfile} 2>&1

bmexe="${bmdir}/benchmark-${benchmark}.exe"

# If it is a verification run, then we just do that
if ${verify}
then
    if qemu-riscv64 -cpu rv64,v=true,vlen=${vlen} ${bmexe} ${size} \
		    ${tot_iters}
    then
	echo "Verification of ${benchmark}: PASS" 2>&1 | tee -a ${logfile}
	exit 0
    else
	echo "Verification of ${benchmark}: FAIL" 2>&1 | tee -a ${logfile}
	exit 1
    fi
fi

# Do two runs of the benchmark and generate the results.

# Temporaries for counts
cntf1="$(mktemp icount1-XXXXXX)"
cntf2="$(mktemp icount2-XXXXXX)"

# Warmup run
res1=$(/usr/bin/time qemu-riscv64 -cpu rv64,v=true,vlen=${vlen} --d plugin \
		     -plugin ${qemuplugindir}/libinsn.so,inline=on -D ${cntf1} \
		     ${bmexe} ${size} ${warmup} 2>&1)

# Benchmark run
res2=$(/usr/bin/time qemu-riscv64 -cpu rv64,v=true,vlen=${vlen} --d plugin \
		     -plugin ${qemuplugindir}/libinsn.so,inline=on -D ${cntf2} \
		     ${bmexe} ${size} ${tot_iters} 2>&1)

# Extract instruction counts (final result is millions of instructions as
# floating point)
icnt1="$(sed -n -e 's/total insns: //p' < ${cntf1})"
icnt2="$(sed -n -e 's/total insns: //p' < ${cntf2})"
micnt=$(runpy "r = (${icnt2} - ${icnt1}) / 1000000.0; print (f'{r:.6f}')")

# Calculate times
user_t1=$(echo ${res1} | sed -e 's/user.*$//')
user_t2=$(echo ${res2} | sed -e 's/user.*$//')
user_t=$(runpy "r = ${user_t2} - ${user_t1}; print (f'{r:.6f}')")

sys_t1=$(echo ${res1} | sed -e 's/^.*user //' -e 's/system.*//')
sys_t2=$(echo ${res2} | sed -e 's/^.*user //' -e 's/system.*//')
sys_t=$(runpy "r = ${sys_t2} - ${sys_t1}; print (f'{r:.6f}')")

bm_t=$(runpy "r = ${user_t} + ${sys_t}; print (f'{r:.6f}')")

# Calculate instructions per iteration
ipi=$(runpy "r = int (${micnt}  * 1000000 / ${iterations}); print (f'{r}')")

# Calcuate ns per instruction
nspi=$(runpy "r = ${bm_t} / ${micnt} * 1000.0; print (f'{r:.6f}')")

case "${format}"
in
    --raw)
	if ${header}
	then
	    printf "%-9s %10s %4s %4s %6s %5s %7s %7s %9s %7s\n" "Benchmark" \
		   "Iterations" "VLEN" "LMUL" "Std" "Size" "Icount" "Time" \
		   "Icnt/iter" "ns/inst"
	fi
	printf "%-9s %10d %4d %4d %6s %5d %7.2f %7.2f %9d %7.2f\n" \
	       "${benchmark}" "${iterations}" "${vlen}" "${lmul}" "${stdlib}" \
               "${size}" "${micnt}" "${bm_t}" "${ipi}" "${nspi}"
	;;
    --csv)
	if ${header}
	then
	    printf '"%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' \
		   "Benchmark" "Iterations" "VLEN" "LMUL" "Std" "Size" \
		   "Icount" "Time" "Icnt/iter" "ns/inst"
	fi
	printf '"%s","%d","%d","%d","%s","%d","%.6f","%.3f","%d","%.2f"\n' \
	       "${benchmark}" "${iterations}" "${vlen}" "${lmul}" "${stdlib}" \
               "${size}" "${micnt}" "${bm_t}" "${ipi}" "${nspi}"
	;;
    --md)
	if ${header}
	then
	    printf "| %-9s | %10s | %4s | %4s | %3s | %5s | %7s | %7s | %9s | %7s |\n" \
		   "Benchmark" "Iterations" "VLEN" "LMUL" "Std" "Size" \
		   "Icount" "Time" "Icnt/iter" "ns/inst"
	    printf "| %-9s | %10s | %4s | %4s | %3s | %5s | %7s | %7s | %9s | %7s |\n" \
		   ":========" "========:" "===:" "===:" ":=:" "====:" \
		   "======:" "======:" "========:" "======:"
	fi
	printf "| %-9s | %10d | %4d | %4d | %3s | %5d | %7.2f | %7.2f | %9d | %7.2f |\n" \
	       "${benchmark}" "${iterations}" "${vlen}" "${lmul}" "${stdlib}" \
	       "${size}" "${micnt}" "${bm_t}" "${ipi}" "${nspi}"
	;;
esac

rm -f "${cntf1}" "${cntf2}"
