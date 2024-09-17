#!/bin/bash

# Copyright (C) 2024 Embecosm Limited <www.embecosm.com>
# Contributor Paolo Savini <paolo.savini@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# Defaults
iterations=10000000
vlens="128 256 512 1024"
data_lens="  1 \
             2 \
             3 \
             4 \
             5 \
             7 \
             8 \
             9 \
            16 \
            25 \
            27 \
            32 \
            49 \
            64 \
            81 \
           125 \
           128 \
           243 \
           256 \
           343 \
           512 \
           625 \
           729 \
          1024 \
          2048 \
          2401 \
          3125 \
          4096 \
          6561 \
          8192 \
         15625"
format="--md"
lmul=8
benchmark="memcpy"

usage () {
    cat <<EOF
Usage ./build-all.sh [--iter <num>]   : Number of iterations of the tests.
                                        Default 1000000
		     [--vlens <list>] : Space separated list of values for the
                                        RVV VLEN parameter. Default "128 256
                                        512 1024"
		     [--lmul <lmul>]  : RVV LMUL parameter. Default 8
                     [--dlens <list>] : Space separated list of data sizes to
                                        use.
		     [--csv | --md]   : Format of table
                     [--help]	      : Print this message and exit

The default list of data points is 1 and all the powers of 2, 3, 5 and 7 up to
5^6.
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
      --vlens)
          shift
	  vlens="$1"
	  ;;
      --lmul)
          shift
	  lmul="$1"
	  ;;
      --dlens)
          shift
	  data_lens="$1"
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
      --benchmark)
	  shift
	  benchmark="$1"
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

# Build the binaries once
if ! make > /dev/null 2>&1
then
    echo "ERROR: run-sequence.sh: Failed to build binaries"
    exit 1
fi

rm -rf vmem.check
rm -rf smem.check

# Header is done once
if [[ "${lmul}" != "1" ]]
then
  if [[ "${format}" == "--md" ]]
  then
      printf "| %10s | %5s | %6s | %7s | %7s | %7s | %10s | %10s | %10s | %10s | %10s | %11s|\n" \
	   "Iterations" "VLEN" "length" "s time" "v1 time" "v$lmul time" \
	   "s Micount" "v1 Micount" "v$lmul Micount" \
	   "s ns/inst" "v1 ns/inst" "v$lmul ns/inst"
      printf "| %10s | %5s | %6s | %7s | %7s | %7s | %10s | %10s | %10s | %10s | %10s | %11s|\n" \
	   "---------:" "----:" "-----:" "------:" "------:" "------:" \
	   "---------:" "---------:" "---------:" \
	   "---------:" "---------:" "----------:"
  else
      printf "\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\"\n" \
	   "Iterations" "VLEN" "length" "s time" "v1 time" "v$lmul time" \
	   "s Micount" "v1 Micount" "v$lmul Micount" \
	   "s ns/inst" "v1 ns/inst" "v$lmul ns/inst"
  fi
else
  if [[ "${format}" == "--md" ]]
  then
      printf "Iterations: %d\n\n" ${iterations}
      printf "| %10s | %5s | %6s | %7s | %7s | %10s | %10s | %10s | %10s |\n" \
	   "Iterations" "VLEN" "length" "s time" "v1 time" \
	   "s Micount" "v1 Micount" \
	   "s ns/inst" "v1 ns/inst"
      printf "| %10s | %5s | %6s | %7s | %7s | %10s | %10s | %10s | %10s |\n" \
	   "---------:" "----:" "-----:" "------:" "------:" \
	   "---------:" "---------:" \
	   "---------:" "---------:"
  else
      printf "\"Iterations\",\"%d\"\n" ${iterations}
      printf "\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\"\n" \
	   "Iterations" "VLEN" "length" "s time" "v1 time" \
	   "s Micount" "v1 Micount" \
	   "s ns/inst" "v1 ns/inst"
  fi
fi

# Do all the runs, but the scalar runs only once
scalar_flag="--scalar"

for vlen in ${vlens}
do
    for l in ${data_lens}
    do
	iters=$((iterations / l))
	./run-${benchmark}.sh ${format} ${scalar_flag} --iter $iters \
	      --len $l --vlen ${vlen} --lmul ${lmul}
    done
    scalar_flag="--no-scalar"
done
