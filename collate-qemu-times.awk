# Awk script to collate QEMU run times

# Copyright (C) 2023 Embecosm Limited
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# Invoke as awk -f collate-times.awk < <input file>

# Dump help message and exit
# \param[in]  rc  Return code on exit
function dohelp(rc) {
    printf "Usage: awk -f collate-qemu-times.awk --txt|--csv|--md --quiet|--verbose < <log file>\n"
    return rc
}

# Print out table header in standad format
function phdr(title, pformat) {
    printf "\n%s\n", title
    for (i = 0; i < length(title); i++)
	printf "="
    printf "\n\n"

    switch (pformat) {
    case "--csv":
	printf "\"Benchmark\",\"Real\",\"User\",\"Sys\"\n"
	break
    case "--md":
	printf "| %-25s | %12s | %12s | %12s |\n", "Benchmark", \
	    "Real", "User", "Sys"
	printf "| %-25s | %12s | %12s | %12s |\n", \
	    ":------------------------", "-----------:", "-----------:", \
	    "-----------:"
	break
    case "--txt":
	printf "%-25s %12s %12s %12s\n", "Benchmark", "Real", "User", "Sys"
	printf "%-25s %12s %12s %12s\n", "---------", "----", "----", "---"
	break
    default:
	break;
    }
}

BEGIN {
    # Get the baseline data
    if (ARGC != 3)
	dohelp(1)
    else {
	switch (ARGV[1]) {
	case "--txt":
	case "--csv":
	case "--md":
	    pformat = ARGV[1]
	    break
	default:
	    dohelp(1)
	}
	switch (ARGV[2]) {
	case "--verbose":
	case "--quiet":
	    verbosity = ARGV[2]
	    break
	default:
	    dohelp(1)
	}

	ARGC = 1
    }
    # Flag to show when we should be capturing data
    capture = 0
}

# Start capturing results
/^Appending benchmark run logs/ {
    capture = 1
}

# Stop capturing results
/^Checking results/ {
    capture = 0
}

# Get name for new set of data
capture && /^Run log for/ {
    bmrun = $4
    split (bmrun, t, "-")
    if ( bm != t[1]) {
	bm = t[1]
	bmtotreal[bm] = 0
	bmtotuser[bm] = 0
	bmtotsys[bm] = 0
	bmmaxreal[bm] = 0
	bmmaxuser[bm] = 0
	bmmaxsys[bm] = 0
    }
}

# Capture real times
capture && /^(real|sys|user)/ {
    patsplit ($2, t, "([[:digit:]]+)|m|.|s")
    tot = t[1] *60 + t[3] + t[5] / 1000
    switch ($1) {
    case "real":
	bmreal[bmrun] = tot
	bmtotreal[bm] += tot
	if (tot > bmmaxreal[bm])
	    bmmaxreal[bm] = tot
	break
    case "user":
	bmuser[bmrun] = tot
	bmtotuser[bm] += tot
	if (tot > bmmaxuser[bm])
	    bmmaxuser[bm] = tot
	break
    case "sys":
	bmsys[bmrun] = tot
	bmtotsys[bm] += tot
	if (tot > bmmaxsys[bm])
	    bmmaxsys[bm] = tot
	break
    }
}

END {
    phdr("Total timings per benchmark", pformat)
    PROCINFO["sorted_in"] = "@ind_str_asc"
    for (bm in bmtotreal) {
	switch (pformat) {
	case "--csv":
	    printf "\"%s\",\"%.3f\",\"%.3f\",\"%.3f\"\n", bm, \
		bmtotreal[bm], bmtotuser[bm], bmtotsys[bm]
	    break
	case "--md":
	    printf "| %-25s | %12.3f | %12.3f | %12.3f |\n", bm, \
		bmtotreal[bm], bmtotuser[bm], bmtotsys[bm]
	    break
	case "--txt":
	    printf "%-25s %12.3f %12.3f %12.3f\n", bm, bmtotreal[bm], \
		bmtotuser[bm], bmtotsys[bm]
	    break
	default:
	}
    }
    if (verbosity == "--verbose") {
	phdr("Timings per run", pformat)
	PROCINFO["sorted_in"] = "@ind_str_asc"
	for (bm in bmreal) {
	    switch (pformat) {
	    case "--csv":
		printf "\"%s\",\"%.3f\",\"%.3f\",\"%.3f\"\n", bm, \
		    bmreal[bm], bmuser[bm], bmsys[bm]
		break
	    case "--md":
		printf "| %-25s | %12.3f | %12.3f | %12.3f |\n", bm, bmreal[bm], \
		    bmuser[bm], bmsys[bm]
		break
	    case "--txt":
		printf "%-25s %12.3f %12.3f %12.3f\n", bm, bmreal[bm], \
		    bmuser[bm], bmsys[bm]
		break
	    default:
	    }
	}
	phdr("Longest run by benchmark", pformat)
	PROCINFO["sorted_in"] = "@ind_str_asc"
	for (bm in bmmaxreal) {
	    switch (pformat) {
	    case "--csv":
		printf "\"%s\",\"%.3f\",\"%.3f\",\"%.3f\"\n", bm, \
		    bmmaxreal[bm], bmmaxuser[bm], bmmaxsys[bm]
		break
	    case "--md":
		printf "| %-25s | %12.3f | %12.3f | %12.3f |\n", bm, \
		    bmmaxreal[bm], bmmaxuser[bm], bmmaxsys[bm]
		break
	    case "--txt":
		printf "%-25s %12.3f %12.3f %12.3f\n", bm, bmmaxreal[bm], \
		    bmmaxuser[bm], bmmaxsys[bm]
		break
	    default:
	    }
	}
    }
}
