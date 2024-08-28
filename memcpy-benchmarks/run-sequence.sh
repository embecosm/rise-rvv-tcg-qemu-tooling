#!/bin/bash

# Copyright (C) 2024 Embecosm Limited <www.embecosm.com>
# Contributor Paolo Savini <paolo.savini@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

iterations=1000000
length=1
fullrun="no"
format="--md"
print_help=false
debug_mode=false
vlen_list=(
128
256
512
1024
)
vlen_list_arg=""
lmul=8
benchmark="memcpy"

usage () {
    cat <<EOF
Usage ./build-all.sh [--iter] <iterations>	: Number of iterations of the tests
		     [--vlen-list] <vlen-list>	: Comma separated list of values for the RVV VLEN parameter
		     [--lmul] <lmul>		: RVV LMUL parameter
                     [--full | --concise]	: How many data sizes to use
		     [--csv | --md]		: Format of table
                     [--help]			: Print this message and exit
EOF
}

# Parse command line options
set +u
until
  opt="$1"
  case "${opt}" in
      --iter)
          shift
	  iterations="$1"
	  ;;
      --vlen-list)
          shift
	  vlen_list_arg="$1"
	  ;;
      --lmul)
          shift
	  lmul="$1"
	  ;;
      --full)
	  fullrun="yes"
	  ;;
      --concise)
	  fullrun="no"
	  ;;
      --md|--csv)
	  format="$1"
	  ;;
      --debug)
	  debug_mode=true
	  ;;
      --benchmark)
	  shift
	  benchmark="$1"
	  ;;
      --help)
	  print_help=true
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

if ${print_help}
then
    usage
    exit 1
fi

if [[ -n $vlen_list_arg ]]
then
  IFS=',' read -r -a vlen_list <<< "$vlen_list_arg"
fi

if [[ "${fullrun}" = "yes" ]]
then
    data_lengths=(
	    1
	    2
	    3
	    4
	    5
	    6
	    7
	    8
	    9
	   10
	   11
	   12
	   13
	   14
	   15
	   16
	   17
	   18
	   19
	   20
	   21
	   22
	   23
	   24
	   25
	   26
	   27
	   28
	   29
	   30
	   31
	   32
	   33
	   34
	   35
	   43
	   49
	   50
	   51
	   52
	   53
	   59
	   60
	   61
	   62
	   63
	   64
	   65
	   66
	   67
	   79
	  127
	  128
	  129
	  130
	  131
	  132
	  133
	  197
	  256
	  281
	  512
	  613
	 1024
	 1579
	 2048
	 2897
	 4096
	 5081
	 8192
	 9103
)
else
	data_lengths=(
	    1
	    2
	    4
	    8
	   16
	   32
	   64
	  128
	  256
	  512
	 1024
	 2048
)
fi

# Build the binaries once
make

rm -rf vmem.check
rm -rf smem.check

# Header is done once
if [[ "${lmul}" != "1" ]]
then
  if [[ "${format}" == "--md" ]]
  then
      printf "Iterations: %d\n\n" ${iterations}
      printf "| %5s | %6s | %7s | %7s | %7s | %10s | %10s | %10s | %10s | %10s | %11s|\n" \
	   "VLEN" "length" "s time" "v1 time" "v$lmul time" \
	   "s Micount" "v1 Micount" "v$lmul Micount" \
	   "s ns/inst" "v1 ns/inst" "v$lmul ns/inst"
      printf "| %5s | %6s | %7s | %7s | %7s | %10s | %10s | %10s | %10s | %10s | %11s|\n" \
	   "----:" "-----:" "------:" "------:" "------:" \
	   "---------:" "---------:" "---------:" \
	   "---------:" "---------:" "----------:"
  else
      printf "\"Iterations\",\"%d\"\n" ${iterations}
      printf "\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\"\n" \
	   "VLEN" "length" "s time" "v1 time" "v$lmul time" \
	   "s Micount" "v1 Micount" "v$lmul Micount" \
	   "s ns/inst" "v1 ns/inst" "v$lmul ns/inst"
  fi
else
  if [[ "${format}" == "--md" ]]
  then
      printf "Iterations: %d\n\n" ${iterations}
      printf "| %5s | %6s | %7s | %7s | %10s | %10s | %10s | %10s |\n" \
	   "VLEN" "length" "s time" "v1 time" \
	   "s Micount" "v1 Micount" \
	   "s ns/inst" "v1 ns/inst"
      printf "| %5s | %6s | %7s | %7s | %10s | %10s | %10s | %10s |\n" \
	   "----:" "-----:" "------:" "------:" \
	   "---------:" "---------:" \
	   "---------:" "---------:"
  else
      printf "\"Iterations\",\"%d\"\n" ${iterations}
      printf "\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\"\n" \
	   "VLEN" "length" "s time" "v1 time" \
	   "s Micount" "v1 Micount" \
	   "s ns/inst" "v1 ns/inst"
  fi
fi

# Do all the runs, but the scalar runs only once
scalar_flag="--scalar"

for vlen in ${vlen_list[@]}
do
    for l in ${data_lengths[@]}; do
	./run-${benchmark}.sh ${format} ${scalar_flag} --iter $iterations --len $l \
			--vlen ${vlen} --lmul ${lmul}
    done
    scalar_flag="--no-scalar"
done
