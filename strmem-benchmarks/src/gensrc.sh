#!/bin/bash

# Copyright (C) 2024 Embecosm Limited <www.embecosm.com>
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# We want all the SiFive sources to be simply parameterizable for LMUL.  It is
# also easier to read without custom names for register.

usage () {
    cat <<EOF
Usage ./gensrc.sh --srcdir <dir>      SiFive source directory.
                  --benchmark <name>  The benchmark to generate.
                  [--help]            Print this help message and exit

The first two options are mandatory, unless --help is specified.
EOF
}

sifivesrcdir=""

# Parse command line options
set +u
until
  opt="$1"
  case "${opt}" in
      --srcdir)
          shift
	  sifivesrcdir="$(cd $(readlink -f $1) ; pwd)"
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

if [[ "x${sifivesrcdir}" == "x" ]]
then
    echo "ERROR: No source dir specified"
    usage
    exit 1
fi

if [[ "x${benchmark}" == "x" ]]
then
    echo "ERROR: No benchmark specified."
    usage
    exit 1
fi

src="${benchmark}_vext.S"
gcc -E -I"${sifivesrcdir}" "${sifivesrcdir}/${src}" | \
    sed -e 's/^    /\t/' \
	-e 's/; .align/\n\t.align/' -e 's/; .type/\n\t.type/' \
	-e 's/.cfi_endproc; /\t.cfi_endproc\n\t/' -e 's/; /\n/' \
	-e 's/;$//' -e 's/^.globl/\t.globl/' -e '/^# /d' \
	-e 's/\(^\t[^ ]\{1,7\}\) \+/\1\t/' \
	-e "s/${benchmark}/${benchmark}_v/g" > "${src}"
