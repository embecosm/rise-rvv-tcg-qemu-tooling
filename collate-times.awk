# Awk script to collate benchmark results

# Copyright (C) 2023, 2024 Embecosm Limited
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# Invoke as awk -f collate-times.awk < <input file>

BEGIN {
    # Get the baseline data
    if ((ARGC < 2) || (ARGC > 3)) {
	printf "Usage: awk -f collate-times.awk [--csv|--md] <base-times> < <input file>\n"
	exit 1
    } else {
	if (ARGC == 2) {
	    pformat = "default"
	    basefile = ARGV[1]
	    ARGC = 1
	}
	else if (ARGV[1] ~ "--csv") {
	    pformat = "csv"
	    basefile = ARGV[2]
	    ARGC = 1
	}
	else if (ARGV[1] ~ "--md") {
	    pformat = "md"
	    basefile = ARGV[2]
	    ARGC = 1
	}
	else {
	    printf "Usage: awk -f collate-times.awk [--csv] <base-times> < <input file>\n"
	    exit 1
	}
    }
    while ((getline < basefile) > 0)
	baset[$1] = $2
}

/[[:digit:]]{3}./ {
    bmres[$1] += $2
}

END {
    switch (pformat) {
    case "csv":
	printf "\"Benchmark\",\"Base (s)\",\"QEMU insns\",\"Ratio\"\n"
	break
    case "md":
	printf "| %-15s | %9s | %15s | %7s |\n", "      Benchmark", \
	    "Base (s)", "QEMU insns", "Ratio"
	printf "| %-15s | %9s | %15s | %7s |\n", ":--------------", \
	    "-------:", "---------:", "----:"
	break
    case "default":
	printf "%-15s %9s %15s %7s\n", "Benchmark", "Base (s)", "QEMU insns", \
	    "Ratio"
	printf "%-15s %9s %15s %7s\n", "---------", "--------", "----------", \
	    "-----"
	break
    default:
	break;
    }
    specprod = 1
    numbm = 0
    PROCINFO["sorted_in"] = "@ind_str_asc"
    for (bm in bmres)
	if (bm in baset) {
	    if (bmres[bm]) {
		ratio = baset[bm] * 1000000000 / bmres[bm]
		specprod *= ratio
		numbm++
	    }
	    else
		ratio = 0

	    switch (pformat) {
	    case "csv":
		if (ratio)
		    printf "\"%s\",\"%d\",\"%d\",\"%.3f\"\n", bm, baset[bm], \
			bmres[bm], ratio
		else
		    printf "\"%s\",\"%d\",\"%d\",\"%s\"\n", bm, baset[bm], \
			bmres[bm], "-"
		break
	    case "md":
		if (ratio)
		    printf "| %-15s | %9d | %15d | %7.3f |\n", bm, baset[bm], \
			bmres[bm], ratio
		else
		    printf "| %-15s | %9d | %15d | %7s |\n", bm, baset[bm], \
			bmres[bm], "-"
		break
	    case "default":
		if (ratio)
		    printf "%-15s %9d %15d %7.3f\n", bm, baset[bm], bmres[bm], \
			ratio
		else
		    printf "%-15s %9d %15d %7s\n", bm, baset[bm], bmres[bm], \
			"-"
		break
	    default:
	    }
	}
	else if (bm !~ "specrand") {
	    if (misslist)
		misslist = misslist ", " bm
	    else
		misslist = bm
	}

    if (numbm) {
	specratio = exp (log (specprod) / numbm)
	switch (pformat) {
	case "csv":
	    printf "\"SPEC ratio\",\"\",\"\",\"%.3f\"\n", specratio
	    break
	case "md":
	    printf "| %-15s | %9s | %15s | %7s |\n", "", "", "", ""
	    printf "| %-15s | %9s | %15s | %7.3f |\n", "SPEC ratio", "", "", \
		specratio
	    break
	case "default":
	    printf "\nSPEC ratio: %7.3f\n", specratio
	    break
	default:
	    break
	}
	if (misslist) {
	    switch (pformat) {
	    case "csv":
		printf "\"Unknown benchmarks\",\"%s\"\n", misslist
		break
	    case "md":
	    case "default":
		printf "\nUnknown benchmarks: %s\n", misslist
		break
	    default:
		break
	    }
	}
    }
}
