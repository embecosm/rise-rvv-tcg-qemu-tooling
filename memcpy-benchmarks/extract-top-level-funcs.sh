#!/bin/bash

# Copyright (C) 2024 Embecosm Limited <www.embecosm.com>
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# A script to extract performance data from memcpy perf runs

set -u

usage () {
    cat <<EOF
Usage ./extract-top-level-funcs.sh : Extract list of top level functions
          --resfile <file>         : Target file to extract
          [--cutoff <num>]         : Percentage at which to stop showing
                                     results (default 1)
          [--total|--self]         : Select based on total (self + children)
                                     or just self.  Default "total"
          [--omit-empty]           : Do not show results if self is 0.00
          [--md | --csv]           : Output results in Markdown (default) or
                                     CSV
EOF
}

tooldir="$(cd $(dirname $(dirname $(readlink -f $0))) ; pwd)"
topdir="$(cd $(dirname ${tooldir}) ; pwd)"
memcpydir="${tooldir}/memcpy-benchmarks"

# Default values
resfile=
cutoff=1
dototal=true
format="--md"
omit_empty=false

set +u
until
  opt="$1"
  case "${opt}"
  in
      --resfile)
	  shift
	  resfile="$(readlink -f $1)"
	  ;;
      --cutoff)
	  shift
	  cutoff="$1"
	  ;;
      --total)
	  dototal=true
	  ;;
      --self)
	  dototal=false
	  ;;
      --omit-empty)
	  omit_empty=true
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

if [[ "x${resfile}" == "x" ]]
then
    echo "ERROR: --resfile required."
    usage
    exit 1
fi

# Temporary file, so we can sort the results
tmpf=$(mktemp extract-top-level-funcs-XXXXXX)

while IFS='' read -r line
do
    if (echo "${line}" | grep -q '\[\.\] [^[:space:]]\+$')
    then
	# Extract the three fields of interest
	pctot=$(echo "${line}" | \
		  sed -e 's/^[[:space:]]\+\([[:digit:]]\+\...\)%.*$/\1/')
	pcself=$(echo "${line}" | \
		  sed -e 's/^[[:space:]]\+[[:digit:]]\+\...%[[:space:]]\+\([[:digit:]]\+\...\)%.*$/\1/')
	func=$(echo ${line} | sed -e 's/^.*\[\.\] \([^[:space:]]\+\)$/\1/')

	# Print fields of interest
	if ${dototal}
	then
	    selector="${pctot}"
	else
	    selector="${pcself}"
	fi

	if [[ "$(echo "${selector}" | sed -e 's/\...$//')" -ge ${cutoff} ]]
	then
	    if ! ${omit_empty} || [[ "${pcself}" != "0.00" ]]
	    then
		case "${format}"
		in
		    --md)
			func=$(echo "\`${func}\`")
			printf "| %8s | %8s | %-45s |\n" "${pctot}" \
			       "${pcself}" "${func}" >> ${tmpf}
			;;
		    --csv)
			printf '"%s","%s","%s"\n' "${pctot}" \
			       "${pcself}" "${func}" >> ${tmpf}
			;;
		esac
	    fi
	fi

	# If pctot is less than the cutoff, then we definitely cannot have any
	# more useful data (since we are ordered on pctot, and pcself can be no
	# greater than pctot)
	if [[ "$(echo "${pctot}" | sed -e 's/\...$//')" -lt ${cutoff} ]]
	then
	    break
	fi
    fi
done < ${resfile}

# Print the results, sorting if necessary
case "${format}"
in
    --md)
	printf "| %8s | %8s | %-45s |\n" "Children" "Self" "Function/address"
	printf "| %8s | %8s | %-45s |\n" "-------:" "-------:" \
	       ":--------------------------------------------"
	;;
    --csv)
	printf '"%s","%s","%s"\n' "Children" "Self" "Function/address"
esac

if ${dototal}
then
    cat < ${tmpf}
else
    # Need to sort
    case "${format}"
    in
	--md)
	    sort -nr -t'|' -k3  < ${tmpf}
	    ;;
	--csv)
	    sort -nr -t'"' -k4  < ${tmpf}
	    ;;
    esac
fi

rm ${tmpf}
