#!/bin/bash

# Copyright (C) 2024 Embecosm Limited <www.embecosm.com>
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# A script to count how often functions are used in profiled memcpy benchmarks

set -u

usage () {
    cat <<EOF
Usage ./count-top-funcs.sh : Count frequency of most use functions
          [--resdir <dir>] : Directory with the results.  Default
                             "res-baseline"
          [--total|--self] : Select results based on total (self + children)
                             or just self.  Default "total"`
          [--md | --csv]   : Output results in Markdown (default) or CSV

The results to be analysed will be in files of the form
"prof-<type>-<size>.res", where type is one of "scalar", "vector-small" or
"vector-large", and size, is the size of the data block in bytes copied on
each iteration.
EOF
}

topdir="$(cd $(dirname $(dirname $(dirname $(readlink -f $0)))) ; pwd)"
memcpydir="${topdir}/tooling/memcpy-benchmarks"
resdir="${memcpydir}/res-baseline"
dototal="--total"
format="--md"

set +u
until
  opt="$1"
  case "${opt}"
  in
      --resdir)
	  shift
	  resdir="$(cd $(readlink -f $1) ; pwd)"
	  ;;
      --total|--self)
	  dototal=$1
	  ;;
      --md|--csv)
	  format="$1"
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

# We create a lot of temporaries!
tmpdir="$(mktemp -d count-top-funcs-XXXXXX)"

# Find out the sizes
dlens="$(ls -1 ${resdir}/prof-scalar-*.res | \
	    sed -e 's/^.*prof-scalar-//' -e 's/\.res$//' | sort -n)"

cd ${memcpydir}
for tp in "scalar" "vector-small" "vector-large"
do
    echo
    echo "${tp}"
    echo
    tmpf1="${tmpdir}/all-${tp}.res"
    tmpf2="${tmpdir}/table-${tp}.res"
    rm -f "${tmpf1}"
    touch "${tmpf1}"
    for l in ${dlens}
    do
	./extract-top-level-funcs.sh --resfile ${resdir}/prof-${tp}-${l}.res \
				     ${dototal} --omit-empty >> ${tmpf1}
    done
    sed -n < ${tmpf1} -e 's/`//gp' | \
	sed -e 's/^|[^|]*|[^|]*| //' -e 's/[[:space:]]*|$//' | \
	sort | uniq -c | sort -nr > ${tmpf2}

    case "${format}"
    in
	--md)
	    printf "| %5s | %-45s |\n" "Count" "Function/address"
	    printf "| %5s | %-45s |\n" "----:" \
		   ":------------------------------------------"
	    ;;
	--csv)
	    printf '"%s","%s"\n' "Count" "Function/address"
    esac

    while IFS='' read -r line
    do
	cnt=$(echo "${line}" | sed -e 's/^[[:space:]]\+//' -e 's/ .*$//')
	func=$(echo "${line}" | \
		   sed -e 's/^[[:space:]]\+[[:digit:]]\+[[:space:]]\+//')

	case "${format}"
	in
	    --md)
		func=$(echo "\`${func}\`")
		printf "| %5s | %-45s |\n" "${cnt}" "${func}"
		;;
	    --csv)
		printf '"%s","%s"\n' "${cnt}" "${func}"
	esac
    done < ${tmpf2}
done

rm -r ${tmpdir}
