#!/bin/bash

# Copyright (C) 2024 Embecosm Limited <www.embecosm.com>
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# A script to extract function performance data from memcpy perf runs

set -u

usage () {
    cat <<EOF
Usage ./profile-all-funcs.sh  : Extract function performance data
          [--resdir <dir>]    : Directory with the results.  Default
                                "res-baseline"
	  [--type <str>]      : What type of result to look at:
                                scalar (default), vector-small or vector-large.
          [--total|--self]    : Select based on total (self + children) or just
                                self.  Default "total"
          [--funclist <list>] : Space separated list of functions to profile,
                                default
                                "helper_lookup_tb_ptr cpu_get_tb_cpu_state"
EOF
}

topdir="$(cd $(dirname $(dirname $(dirname $(readlink -f $0)))) ; pwd)"
memcpydir=${topdir}/tooling/memcpy-benchmarks

# Default values
resdir="${memcpydir}/res-baseline"
restype="scalar"
dototal=true
funclist="helper_lookup_tb_ptr cpu_get_tb_cpu_state"

set +u
until
  opt="$1"
  case "${opt}"
  in
      --resdir)
	  shift
	  resdir="$(cd $(readlink -f $1) ; pwd)"
	  ;;
      --type)
	  shift
	  case "$1"
	  in
	      scalar|vector-small|vector-large)
		  restype="$1"
		  ;;
	      *)
		  echo "ERROR: Uknown results type: \"$1\""
		  usage
		  exit 1
		  ;;
	  esac
	  ;;
      --total)
	  dototal=true
	  ;;
      --self)
	  dototal=false
	  ;;
      --funclist)
	  shift
	  funclist="$1"
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

# Temporary file for intermediaries
tmpf="$(mktemp profile-all-funcs-XXXXXX)"
tmpcsv="$(mktemp profile-all-funcs-XXXXXX.csv)"

# Find out the sizes
cd ${resdir}
dlens=$(ls -1 prof-${restype}-*.res | \
	    sed -e "s/^prof-${restype}-//" -e 's/\.res$//' | sort -n)

# Build up the results in a list
declare -A reslist
for f in ${funclist}
do
    reslist[${f}]="%${f}"
done
res_title="%Size"

# Extract the data
cd ${memcpydir}
for l in ${dlens}
do
    res_title="${res_title}#${l}"
    ./extract-top-level-funcs.sh --md \
	--resfile ${resdir}/prof-${restype}-${l}.res > ${tmpf}

    for f in ${funclist}
    do
	# Select which percentage we are reporting
	if ${dototal}
	then
	    pc=$(grep ${f} < ${tmpf} | \
		 sed -n -e 's/|[^|]\+|[[:space:]]\+\([^[:space:]]\+\).*$/\1/p')
	else
	    pc=$(grep ${f} < ${tmpf} | \
		 sed -n -e 's/|[[:space:]]\+\([^[:space:]]\+\).*$/\1/p')
	fi

	if [[ "x${pc}" == "x" ]]
	then
	    res="0.0000"
	elif [[ ${pc} == "100.0" ]]
	then
	    res="1.0000"
	else
	    intpart=$(echo "${pc}" | \
			  sed -e 's/\([[:digit:]]\+\)\.[[:digit:]]\+$/\1/')
	    fracpart=$(echo "${pc}" | \
			   sed -e 's/[[:digit:]]\+\.\([[:digit:]]\+\)$/\1/')
	    res=$(printf "0.%02d%2s" "${intpart}" "${fracpart}")

	fi
	reslist[${f}]="${reslist[${f}]}#${res}"
    done
done

# Print it all out
res_title="${res_title}%"
echo "${res_title}" | sed -e 's/%/"/g' -e 's/#/","/g' > ${tmpcsv}
for f in ${funclist}
do
    reslist[${f}]="${reslist[${f}]}%"
    echo "${reslist[${f}]}" | sed -e 's/%/"/g' -e 's/#/","/g' >> ${tmpcsv}
done

csvtool transpose ${tmpcsv}

rm -f ${tmpf}
rm -f ${tmpcsv}
