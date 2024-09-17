#!/bin/bash

# Copyright (C) 2024 Embecosm Limited <www.embecosm.com>
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# A script to run Linux perf on lots of memcpy benchmarks

set -u

usage () {
    cat <<EOF
Usage: ./run-perf.sh       : Run Linux perf on memcpy benchmarks
          [--bytes <num>]  : Total bytes to copy.  Default 1,000,000,000
          [--resdir <dir>] : Directory in which to place the results.  Default
                             is the directory holding this script.
          [--sizes <list>] : Space separated list of the data sizes to use when
                             creating results.  Default list is all the powers
                             of 2, 3, 5 and 7 up to 5^6

The results will be three sets of files of the form "prof-<type>-<size>.res",
where type is one of "scalar", "vector-small" or "vector-large", and size, is
the size of the data block copied on each iteration.

The total number of iterations for each test is determined by the number given
in the "--bytes" argument divided by the size of the data block being used for
the run.

"perf record" is run using DWARF to determine the call graph.  This gives
accurate results, but is slow.  Expect each iteration to take of the order of
20 minutes on a decent server.
EOF
}

memcpydir="$(cd $(dirname $(readlink -f $0)) ; pwd)"

# Default values
bytes="1000000000"
resdir="${memcpydir}"
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

set +u
until
  opt="$1"
  case "${opt}"
  in
      --bytes)
	  shift
	  bytes="$1"
	  ;;
      --resdir)
	  shift
	  resdir="$(cd $(readlink -f $1) ; pwd)"
	  ;;
      --sizes)
	  shift
	  data_lens="$1"
	  ;;
      --help)
	  usage
	  exit 0
	  ;;
      ?*)
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

mkdir -p "${resdir}"

for dlen in ${data_lens}
do
    iters=$((bytes / dlen))
    echo "=== Data len ${dlen}, iterations ${iters}"
    echo " - scalar record"
    time perf record -g -m 16M --call-graph dwarf,4096 -- \
	 qemu-riscv64 -cpu "rv64,v=true,vlen=128" \
	 smemcpy.exe ${dlen} ${iters} > /dev/null
    echo " - scalar report"
    time perf report --stdio --call-graph "graph,0.1,caller,function" \
	 -k /tmp/vmlinux | \
	sed -e 's/[[:space:]]*$//' > ${resdir}/prof-scalar-${dlen}.res
    echo " - small vector record"
    time perf record -g -m 16M --call-graph dwarf -- \
	 qemu-riscv64 -cpu "rv64,v=true,vlen=128" \
	 vmemcpy1.exe ${dlen} ${iters} > /dev/null
    echo " - small vector report"
    time perf report --stdio --call-graph "graph,0.1,caller,function" \
	 -k /tmp/vmlinux | \
	sed -e 's/[[:space:]]*$//' > ${resdir}/prof-vector-small-${dlen}.res
    echo " - large vector record"
    time perf record -g -m 16M --call-graph dwarf,4096 -- \
	 qemu-riscv64 -cpu "rv64,v=true,vlen=1024" \
	 vmemcpy8.exe ${dlen} ${iters} > /dev/null
    echo " - large vector report"
    time perf report --stdio --call-graph "graph,0.1,caller,function" \
	 -k /tmp/vmlinux | \
	sed -e 's/[[:space:]]*$//' > ${resdir}/prof-vector-large-${dlen}.res
done
