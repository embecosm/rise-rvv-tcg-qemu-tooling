#!/bin/bash

# Copyright (C) 2024 Embecosm Limited <www.embecosm.com>
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# A script to run Linux perf on the SPEC 628.pop2_s benchmark.

set -u

usage () {
    cat <<EOF
Usage ./run-spec-pop2.sh        : Run the SPEC 2017 628.pop2_2 benchmark under
                                  perf
          [--reportfile <file>] : Name of the report file (relative to tooling
                                  directory).  Default: prof-628.pop2_s.res
          [--specdir <dir>]     : Use this as the directory with the SPEC CPU
                                  2017 installation.  Default
                                  ${topdir}/install/spec-2024-08-14-08-41-03
EOF
}

topdir="$(cd $(dirname $(dirname $(readlink -f $0))) ; pwd)"
tooldir="${topdir}/tooling"
specdir="${topdir}/install/spec-2024-08-14-08-41-03"
reportfile=prof-628.pop2_s.res

set +u
until
  opt="$1"
  case "${opt}" in
      --reportfile)
	  shift
	  reportfile=$(readlink -f $1)
	  ;;
      --specdir)
	  shift
	  specdir="$(cd $(readlink -f $1) ; pwd)"
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

export PATH="${topdir}/install/bin:${PATH}"

speccpudir="${specdir}/benchspec/CPU"
cd ${speccpudir}/628.pop2_s/run/run_base_test_riscv64-qemu-default.0000

echo "Recording..."
time perf record -g -m 16M --call-graph dwarf,4096 -- qemu-riscv64 \
     -cpu "rv64,zicsr=true,v=true,vext_spec=v1.0,zfh=true,zvfh=true" \
     ./speed_pop2_base.riscv64-qemu-default \
     > pop2_s-perf.out 2>> pop2_s-perf.err
echo "Generating report..."
time perf report --stdio --call-graph "graph,0.1,caller,function" \
     -k /tmp/vmlinux | \
    sed -e 's/[[:space:]]*$//' > ${topdir}/tooling/${reportfile}
