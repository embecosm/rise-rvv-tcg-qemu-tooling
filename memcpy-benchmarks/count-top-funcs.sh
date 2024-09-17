#!/bin/bash

# Copyright (C) 2024 Embecosm Limited <www.embecosm.com>
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# A script to count how often functions are used in profiled memcpy benchmarks

set -u

usage () {
    cat <<EOF
Usage ./count-top-funcs.sh       : Count frequency of most use functions
          [--resdir <dir>]       : Directory with the results.  Default
                                   "res-baseline"
          [--total|--self]       : Select results based on total (self +
                                   children) or just self.  Default "total"
          [--types <list>]       : List of result file types, default
                                   "scalar vector-small vector-large"
          [--cutoff <val>]       : Cutoff for count to be presented.  Default 0
          [--md | --csv | --raw] : Output results in Markdown, CSV or as a raw
                                   string for use as the --funclist argument
                                   of profile-all-funcs.sh

The results to be analysed will be in files of the form
"prof-<type>-<size>.res", where type is one of the types listed in the
--types argument, and size, is the size of the data block in bytes copied on
each iteration.
EOF
}

# Directories
tooldir="$(cd $(dirname $(dirname $(readlink -f $0))) ; pwd)"
topdir="$(cd $(dirname ${tooldir}) ; pwd)"
memcpydir="${tooldir}/memcpy-benchmarks"

# Defaults
resdir="${memcpydir}/res-baseline"
dototal="--total"
types="scalar vector-small vector-large"
cutoff="0"
format="--raw"

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
      --types)
	  shift
	  types="$1"
	  ;;
      --cutoff)
	  shift
	  cutoff="$1"
	  ;;
      --md|--csv|--raw)
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

cd ${memcpydir}
for tp in ${types}
do
    tmpf1="${tmpdir}/all-${tp}.res"
    tmpf2="${tmpdir}/table-${tp}.res"
    rm -f "${tmpf1}"
    touch "${tmpf1}"

    # Find out the sizes
    dlens=$(ls -1 ${resdir}/prof-${tp}-*.res | \
		sed -e "s/^.*prof-${tp}-//" -e 's/\.res$//' | sort -n)
    nlens=$(echo "${dlens}" | wc -l)
    printf "%s %d results\n" "${tp}" "${nlens}"

    # Extract all the desired data
    for l in ${dlens}
    do
	echo -n "."
	./extract-top-level-funcs.sh --resfile ${resdir}/prof-${tp}-${l}.res \
				     ${dototal} --omit-empty >> ${tmpf1}
    done
    echo
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

    funclist=
    while IFS='' read -r line
    do
	cnt=$(echo "${line}" | sed -e 's/^[[:space:]]\+//' -e 's/ .*$//')
	if [[ "${cnt}" -lt "${cutoff}" ]]
	then
	    break
	fi

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
		;;
	    --raw)
		if [[ "x${funclist}" == "x" ]]
		then
		    funclist="${func}"
		else
		    funclist="${funclist} ${func}"
		fi
	esac
    done < ${tmpf2}

    if [[ "${format}" == "--raw" ]]
    then
	printf '"%s"\n' "${funclist}"
    fi
done

rm -r ${tmpdir}
