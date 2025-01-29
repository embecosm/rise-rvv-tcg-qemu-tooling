# Run all the fault-only-first load benchmarks

# Copyright (C) 2025 Embecosm Limited <www.embecosm.com>
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

set -u

# Produce help message
usage () {
    cat <<EOF
Usage ./do-all.sh                      : Benchmark whole word load/store.
                   [--nloops <count>]  : Number of iterations of the test
                                         program (default 10000000)
                   [--nstats <count>]  : Number of times to repeat each test
                                         for statistical analysis (default 10)
                   [--ldcount <count>] : Now many duplicate of the instruction
                                         we are counting (default 10)
                   [--base <id>]       : Commit of the QEMU version to use as
                                         baseline
                   [--test <id>]       : Commit of the QEMU version to use be
                                         tested against the baseline
                   [--help]            : Print this message and exit

The QMEU are assumed to have been built without plugins enabled, with the
binary installed in ../../install/qemu-${qid}-no-plugin/bin, where qid is the
argument to --base or --test.
EOF
}

# Build the exe
# $1 Instruction
# $2 Instruction count
# $3 "load" or "store"
buildit() {
    local i=$1
    local icount=$2
    local lmul=$3
    local elem=$(echo "${i}" | sed -e 's/vl//' -e 's/ff//')
    # Single instr build
    make clean > /dev/null 2>&1
    make LD_CNT=${icount} LD_LOOP_CNT=${nloops} VLDOP=${i} \
	 DOMASK=0 ELEM="${elem}" LMUL=${lmul}   ${i}.exe > /dev/null 2>&1
}

# Return the time for doing a single run. Assumes the exe has been built
# $1 VLEN
# $2 Instruction
# $3 QEMU commit
runone() {
    local vl=$1
    local i=$2
    local qid=$3

    local OLDPATH=${PATH}
    PATH=../../install/qemu-${qid}-no-plugin/bin:${OLDPATH}
    (time qemu-riscv64 -cpu rv64,v=true,vlen=${vl} ${i}.exe) \
	> ${tmpf} 2>&1
    local u=$(sed -n -e 's/user[[:space:]]*0m\(.\+\)s$/\1/p' < ${tmpf})
    local s=$(sed -n -e 's/sys[[:space:]]*0m\(.\+\)s$/\1/p' < ${tmpf})
    PATH=${OLDPATH}
    t=$(echo "print(${u} + ${s})" | python3)
    printf "%.3f" ${t}
}

# Run a single measurement
# $1 VLEN
# $2 LMUL
# $3 Instruction
runit() {
    local vl=$1
    local lmul=$2
    local i=$3
    local res=""
    # We repeat until we get a meaningful result.  This should mean we skip
    # some silly results due to chron jobs
    while [[ "x${res}" == "x" ]]
    do
	# single instruction runs for base and test QEMU
	buildit ${i} 1 ${lmul}
	local tbase1=$(runone ${vl} ${i} ${qemubase})
	local ttest1=$(runone ${vl} ${i} ${qemutest})
	# ldcount + 1 instruction runs for base and test
	ninst=$((ldcount + 1))
	buildit ${i} ${ninst} ${lmul}
	local tbasen=$(runone ${vl} ${i} ${qemubase})
	local ttestn=$(runone ${vl} ${i} ${qemutest})
	# Calculate net instructions times for base and test
	local tdbase=$(echo "print(${tbasen} - ${tbase1})" | python3)
	local tdtest=$(echo "print(${ttestn} - ${ttest1})" | python3)
	res=$(echo "print(${tdbase} / ${tdtest} - 1 \
                          if (${tdbase} > 0) and (${tdtest} > 0) else '')" \
		  | python3)
	restxt="GOOD:"
	if [[ "x${res}" == "x" ]]
	then
	    restxt="BAD:"
	fi
	printf "%-5s %-7s %2s %4d %.3f %.3f\n" "${restxt}" "${i}" "${lmul}" \
	       ${vl} ${tdbase} ${tdtest} >> ${logf}

    done
    printf "%.3f" ${res}
}

ldinstr="vle8ff  \
	 vle16ff \
	 vle32ff \
	 vle64ff"

vlenlist="128 256 512 1024"

lmullist="m1 m2 m4 m8"

tmpf=$(mktemp fault-first-load-XXXXXX.txt)
logf=rundata.log

ldresf="ldres.csv"

# Defaults for variables
nloops=10000000
nstats=10
ldcount=10
qemubase="6528013b5f"
qemutest="db95037b42"

# Parse command line options
set +u
until
  opt="$1"
  case "${opt}" in
      --nloops)
	  shift
	  nloops="$1"
	  ;;
      --nstats)
	  shift
	  nstats="$1"
	  ;;
      --ldcount)
	  shift
	  ldcount="$1"
	  ;;
      --base)
	  shift
	  qemubase="$1"
	  ;;
      --test)
	  shift
	  qemutest="$1"
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

rm -f ${logf}

# All the load instructions
echo "Fault only first load instructions"
printf '"vlen","lmul","ldop"' > ${ldresf}
for n in $(seq ${nstats})
do
    printf ',"run %d"' ${n} >> ${ldresf}
done
printf '\n' >> ${ldresf}

for vl in ${vlenlist}
do
    for lmul in ${lmullist}
    do
	for i in ${ldinstr}
	do
	    printf '"%d","%s","%s"' ${vl} ${lmul} ${i} >> ${ldresf}
	    printf "VLEN = %4d, LMUL = %2s: %-7s " ${vl} ${lmul} ${i}
	    for n in $(seq ${nstats})
	    do
		r=$(runit ${vl} ${lmul} ${i})
		printf ',"%.3f"' ${r} >> ${ldresf}
		printf "."
	    done
	    printf '\n' >> ${ldresf}
	    printf "\n"
	done
    done
done

# Tidy up
make clean > /dev/null 2>&1
rm -f ${tmpf}
