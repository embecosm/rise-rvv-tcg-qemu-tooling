# Awk script to extract commands to run SPEC CPU 2017 benchmarks

# Copyright (C) 2023 Embecosm Limited
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# Invoke as awk -f runspec-breakout.awk <bm-template> < <input file>

BEGIN {
    # State machine variables
    invoking = 0
    verifying = 0

    # Get the template for the scripts
    if (ARGC != 2) {
	printf "Usage: awk -f runspec-breakout.awk <bm-template> < <input file>\n"
	exit 1
    } else {
	bmtemplate = ARGV[1]
	ARGC = 1
    }
}

/Benchmark invocation/ {
    invoking = 1
    verifying = 0
    invnum = 0
}

/Benchmark verification/ {
    invoking = 0
    verifying = 1
    invnum = 0
}

invoking && /# Starting run for copy/ {
    scriptfile = bmtemplate "-run-" invnum ".sh"
    invnum++
}

verifying && /# Starting run for copy/ {
    scriptfile = bmtemplate "-check-" invnum ".sh"
    invnum++
}

(invoking || verifying) && /^cd/ {
    print $0 > scriptfile
}

invoking && /^qemu-riscv64/ {
    print $0 > scriptfile
}

verifying && /^[^[:space:]]+\/specperl/ {
    print $0 > scriptfile
}

verifying && /The log for this run is in/ {
    print $8
}
