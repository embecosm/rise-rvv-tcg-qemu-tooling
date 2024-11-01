#!/bin/bash

# Copyright (C) 2024 Embecosm Limited <www.embecosm.com>
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# Plot the graphs for one benchmark.  A total of 6 graphs
# - new v old for scalar, small-vector and large-vector ns/instr
# - new v old for scalar, small-vector and large-vector icount/iteration

set -u

# General help message.
usage () {
    cat <<EOF
Usage ./plot-one-benchmark.sh
    --benchmark <name>                : Name of the function being plotted
    --old-qemu <str>                  : Id for the old (i.e. baseline) QEMU
                                        (e.g. git hash)
    --new-qemu <str>                  : Id for the new QEMU (e.g. git
                                        hash)
    --old-scalar-data <csvfile>       : Data to plot
    --new-scalar-data <csvfile>       : Data to plot
    --old-small-vector-data <csvfile> : Data to plot
    --new-small-vector-data <csvfile> : Data to plot
    --old-large-vector-data <csvfile> : Data to plot
    --new-small-large-data <csvfile>  : Data to plot
    --help                            : Print this help and exit

All arguments are mandatory.  It is anticipated this script will be driven
from a master script generating all the results.
EOF
}

# Check the argument is not empty. First argument is the name of the argument,
# second is the value to check
check_set () {
    if [[ "x$2" == "x" ]]
    then
	echo "ERROR: Argument ${1} not specified"
	failed=true
    fi
}

# Use csvtool to find the largest number in a named column of a CSV file.
# First argument is the name of the column, second is the CSV file.
find_max () {
    csvtool namedcol "${1}" "${2}" | csvtool drop 1 - | sort -n | tail -1
}

# Function to run its argument under python
runpy () {
    echo "${1}" | python
}

# Find an appropriate range for the supplied argument. Add 20% and then 
find_range () {
    raw=$(runpy "r = $1 * 1.2; print (f'{r:.6f}')")
    order=$(runpy "import math; \
                   r = math.pow (10,(math.ceil (math.log10(${raw}))-2)); \
                   print (f'{r}')")
    dig2=$(runpy "i = int (${raw} / ${order}); print (f'{i}')")
    # Brute force approach...
    if [[ ${dig2} -eq 10 ]]
    then
	rg=10
    elif [[ ${dig2} -le 12 ]]
    then
	rg=12
    elif [[ ${dig2} -le 15 ]]
    then
	rg=15
    elif [[ ${dig2} -le 20 ]]
    then
	rg=20
    elif [[ ${dig2} -le 25 ]]
    then
	rg=25
    elif [[ ${dig2} -le 30 ]]
    then
	rg=30
    elif [[ ${dig2} -le 40 ]]
    then
	rg=40
    elif [[ ${dig2} -le 50 ]]
    then
	rg=50
    elif [[ ${dig2} -le 60 ]]
    then
	rg=60
    elif [[ ${dig2} -le 80 ]]
    then
	rg=80
    else
	rg=100
    fi
    runpy "r = ${rg} * ${order}; print (f'{r}')"
}

# Find the actual range to use for a pair of CSV files.  First argument is the
# column name, the second and third are CSV files
range_for_col () {
    m=$(find_max "${1}" "${2}")
    or=$(find_range "${m}")
    m=$(find_max "${1}" "${3}")
    nr=$(find_range "${m}")
    runpy "r = max (${or}, ${nr}); print (f'{r}')"
}

# Standard directories
tooldir="$(cd $(dirname $(dirname $(readlink -f $0))) ; pwd)"
topdir="$(cd $(dirname ${tooldir}) ; pwd)"
strmemdir="${tooldir}/strmem-benchmarks"

export PATH="${topdir}/install/bin:${PATH}"

# Default values
benchmark=""
old_qemu=""
new_qemu=""
old_scalar_csv=""
new_scalar_csv=""
old_small_vector_csv=""
new_small_vector_csv=""
old_large_vector_csv=""
new_large_vector_csv=""

# Parse command line options
set +u
until
  opt="$1"
  case "${opt}"
  in
      --benchmark)
	  shift
	  benchmark="$1"
	  ;;
      --old-qemu)
	  shift
	  old_qemu="$1"
	  ;;
      --new-qemu)
	  shift
	  new_qemu="$1"
	  ;;
      --old-scalar-data)
	  shift
	  old_scalar_csv="$(readlink -f $1)"
	  ;;
      --new-scalar-data)
	  shift
	  new_scalar_csv="$(readlink -f $1)"
	  ;;
      --old-small-vector-data)
	  shift
	  old_small_vector_csv="$(readlink -f $1)"
	  ;;
      --new-small-vector-data)
	  shift
	  new_small_vector_csv="$(readlink -f $1)"
	  ;;
      --old-large-vector-data)
	  shift
	  old_large_vector_csv="$(readlink -f $1)"
	  ;;
      --new-large-vector-data)
	  shift
	  new_large_vector_csv="$(readlink -f $1)"
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

# Check all arguments set
failed=false
check_set "--benchmark"             "${benchmark}"
check_set "--old-qemu"              "${old_qemu}"
check_set "--new-qemu"              "${new_qemu}"
check_set "--old-scalar-data"       "${old_scalar_csv}"
check_set "--new-scalar-data"       "${new_scalar_csv}"
check_set "--old-small-vector-data" "${old_small_vector_csv}"
check_set "--new-small-vector-data" "${new_small_vector_csv}"
check_set "--old-large-vector-data" "${old_large_vector_csv}"
check_set "--new-small-large-data"  "${new_large_vector_csv}"

if ${failed}
then
    usage
    exit 1
fi

# Work out clean Y ranges.
scalar_nspi_range=$(range_for_col "ns/inst" "${old_scalar_csv}" \
				  "${new_scalar_csv}")
small_vector_nspi_range=$(range_for_col "ns/inst" "${old_small_vector_csv}" \
					"${new_small_vector_csv}")
large_vector_nspi_range=$(range_for_col "ns/inst" "${old_large_vector_csv}" \
					"${new_large_vector_csv}")
y1=$(range_for_col "Icnt/iter" "${old_scalar_csv}" \
		   "${new_scalar_csv}")
y2=$(range_for_col "Icnt/iter" "${old_small_vector_csv}" \
		   "${new_small_vector_csv}")
y3=$(range_for_col "Icnt/iter" "${old_large_vector_csv}" \
		   "${new_large_vector_csv}")
ipi_range=$(runpy "r = max (${y1}, ${y2}, ${y3}); print (r)")

# Now plot all the graphs
gnuplot -e "benchmark='${benchmark}'" \
	-e "old_qemu='${old_qemu}'" \
	-e "new_qemu='${new_qemu}'" \
	-e "old_scalar_csv='${old_scalar_csv}'" \
	-e "new_scalar_csv='${new_scalar_csv}'" \
	-e "old_small_vector_csv='${old_small_vector_csv}'" \
	-e "new_small_vector_csv='${new_small_vector_csv}'" \
	-e "old_large_vector_csv='${old_large_vector_csv}'" \
	-e "new_large_vector_csv='${new_large_vector_csv}'" \
	-e "scalar_nspi_range='${scalar_nspi_range}'" \
	-e "small_vector_nspi_range='${small_vector_nspi_range}'" \
	-e "large_vector_nspi_range='${large_vector_nspi_range}'" \
	-e "ipi_range='${ipi_range}'" \
        plot-one-benchmark.gnuplot

mkdir -p graphs
ps2pdf -sPAGESIZE=a4 ${benchmark}.ps graphs/${benchmark}.pdf
rm ${benchmark}.ps
