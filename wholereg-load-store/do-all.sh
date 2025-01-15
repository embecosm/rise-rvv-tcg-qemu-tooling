# Run all the whole word load/store benchmarks

# Copyright (C) 2025 Embecosm Limited <www.embecosm.com>
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

set -u

# Produce help message
usage () {
    cat <<EOF
Usage ./do-all.sh                     : Benchmark whole word load/store.
                   [--nloops <count>] : Number of iterations of the test
                                        program (default 10000000)
                   [--nstats <count>] : Number of times to repeat each test
                                        for statistical analysis (default 10).
                   [--help]           : Print this message and exit
EOF
}

# Build the exe
# $1 Instruction
# $2 Instruction count
# $3 "load" or "store"
buildit() {
    local i=$1
    local icount=$2
    local lors=$3
    # Single instr build
    make clean > /dev/null 2>&1
    if [[ "x${lors}" == "xload" ]]
    then
	make LD_CNT=${icount} LD_LOOP_CNT=${nloops} VLDOP=${i} \
	     ${i}.exe > /dev/null 2>&1
    elif [[ "x${lors}" == "xstore" ]]
    then
	make ST_CNT=${icount} ST_LOOP_CNT=${nloops} VSTOP=${i} \
	     ${i}.exe > /dev/null 2>&1
    else
	exit 1
    fi
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
# $2 Instruction
# $3 "load" or "store"
runit() {
    local vl=$1
    local i=$2
    local lors=$3
    local res=""
    # We repeat until we get a meaningful result.  This should mean we skip
    # some silly results due to chron jobs
    while [[ "x${res}" == "x" ]]
    do
	# single instruction runs for base and test QEMU
	buildit ${i} 1 ${lors}
	local tbase1=$(runone ${vl} ${i} ${qemubase})
	local ttest1=$(runone ${vl} ${i} ${qemutest})
	# 11 instruction runs for base and test
	buildit ${i} 11 ${lors}
	local tbase11=$(runone ${vl} ${i} ${qemubase})
	local ttest11=$(runone ${vl} ${i} ${qemutest})
	# Calculate net instructions times for base and test
	local tdbase=$(echo "print(${tbase11} - ${tbase1})" | python3)
	local tdtest=$(echo "print(${ttest11} - ${ttest1})" | python3)
	res=$(echo "print(${tdbase} / ${tdtest} - 1 \
                          if (${tdbase} > 0) and (${tdtest} > 0) else '')" \
		  | python3)
    done
    printf "%.3f" ${res}
}

ldinstr="vl1re8  \
	 vl1re16 \
	 vl1re32 \
	 vl1re64 \
         vl2re8  \
	 vl2re16 \
	 vl2re32 \
	 vl2re64 \
         vl4re8  \
	 vl4re16 \
	 vl4re32 \
	 vl4re64 \
         vl8re8  \
	 vl8re16 \
	 vl8re32 \
	 vl8re64"

stinstr="vs1r vs2r vs4r vs8r"

vlenlist="128 256 512 1024"

qemubase="6528013b5f"
qemutest="db95037b42"
tmpf=$(mktemp whole-word-load-store-XXXXXX.txt)

ldresf="ldres.csv"
stresf="stres.csv"

# Defaults for variables
nloops=10000000
nstats=10

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

# All the load instructions
echo "Whole word load instructions"
printf '"vlen","ldop"' > ${ldresf}
for n in $(seq ${nstats})
do
    printf ',"run %d"' ${n} >> ${ldresf}
done
printf '\n' >> ${ldresf}

for vl in ${vlenlist}
do
    for i in ${ldinstr}
    do
	printf '"%d","%s"' ${vl} ${i} >> ${ldresf}
	printf "VLEN = %4d: %-7s " ${vl} ${i}
	for n in $(seq ${nstats})
	do
	    r=$(runit ${vl} ${i} "load")
	    printf ',"%.3f"' ${r} >> ${ldresf}
	    printf "."
	done
	printf '\n' >> ${ldresf}
	printf "\n"
    done
done

# All the store instructions
echo "Whole word store instructions"
printf '"vlen","stop"' > ${stresf}
for n in $(seq ${nstats})
do
    printf ',"run %d"' ${n} >> ${stresf}
done
printf '\n' >> ${stresf}

for vl in ${vlenlist}
do
    for i in ${stinstr}
    do
	printf '"%d","%s"' ${vl} ${i} >> ${stresf}
	printf "VLEN = %4d: %-7s " ${vl} ${i}
	for n in $(seq ${nstats})
	do
	    r=$(runit ${vl} ${i} "store")
	    printf ',"%.2f"' ${r} >> ${stresf}
	    printf "."
	done
	printf '\n' >> ${stresf}
	printf "\n"
    done
done

# Tidy up
make clean > /dev/null 2>&1
rm -f ${tmpf}
