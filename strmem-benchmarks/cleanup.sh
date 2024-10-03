#!/bin/bash

# Copyright (C) 2024 Embecosm Limited <www.embecosm.com>
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# Clean up after problem benchmark run.

set -u

if [[ $# -eq 2 ]]
then
    sig="$1"
else
    sig="-KILL"
fi

tmpe="$(mktemp cleanup-XXXXXX.sh)"

# Find miscreant processes
ps x | grep run-one-benchmark | \
    sed -e "s/[[:space:]]*\([^[:space:]]\+\).*\$/kill ${sig} \1/" >> ${tmpe}
ps x | grep qemu-riscv64 | \
    sed -e "s/[[:space:]]*\([^[:space:]]\+\).*\$/kill ${sig} \1/" >> ${tmpe}

echo "Found $(wc -l < ${tmpe}) processes"

# Terminate processes with extreme prejudice
bash ${tmpe} > /dev/null 2>&1
rm ${tmpe}

# Remove unwanted files and directories
if ls -1d r1b-src-?????? > /dev/null 2>&1
then
    nd="$(ls -1d r1b-src-?????? | wc -l)"
else
    nd="0"
fi

if ls -1d r1b-??????.csv icount?-?????? > /dev/null 2>&1
then
    nf="$(ls -1 r1b-??????.csv icount?-?????? | wc -1)"
else
    nf="0"
fi

echo "Removing ${nd} directories and ${nf} files"
rm -rf r1b-src-??????
rm -f r1b-??????.csv
rm -f icount?-??????
