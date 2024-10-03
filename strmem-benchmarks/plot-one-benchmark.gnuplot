#!/bin/bash

# Copyright (C) 2024 Embecosm Limited <www.embecosm.com>
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# The GNU plot configuration to go with plot-one-benchmark.sh

# Use CSV input with a header row
set datafile separator ','
set key autotitle columnhead

# Plot to PDF US Letter
set terminal postscript enhanced color landscape 'Muli,8'
set output benchmark.".ps"

set xlabel "Size"
set style line 100 lt 1 lc rgb "grey" lw 0.5
set xtics out 10 nomirror
set logscale x 10
set ytics out autofreq nomirror
set grid ytics

# Colors correspond to the first six default colours used in Google
# spreadsheet graphs
set style line 101 lw 3 lt rgb "#4285f4"
set style line 102 lw 3 lt rgb "#ea4335"
set style line 103 lw 3 lt rgb "#fbbc04"
set style line 104 lw 3 lt rgb "#34a853"
set style line 105 lw 3 lt rgb "#ff6d01"
set style line 106 lw 3 lt rgb "#46bdc6"

set key left top Left reverse # legend placement

# Now all the plots
set multiplot layout 2,2 title benchmark." performance" \
    margins 0.02, 1.00, 0.01, 0.90 spacing 0.1

set title "Instruction counts"
set yrange [0:ipi_range]
set ylabel "instructions/iteration"
plot old_scalar_csv using (column("Size")):(column("Icnt/iter")) \
     title old_qemu." scalar" with lines ls 101, \
     new_scalar_csv using (column("Size")):(column("Icnt/iter")) \
     title new_qemu." scalar" with lines ls 102, \
     old_small_vector_csv using (column("Size")):(column("Icnt/iter")) \
     title old_qemu." small vector" with lines ls 103, \
     new_small_vector_csv using (column("Size")):(column("Icnt/iter")) \
     title new_qemu." small vector" with lines ls 104, \
     old_large_vector_csv using (column("Size")):(column("Icnt/iter")) \
     title old_qemu." large vector" with lines ls 105, \
     new_large_vector_csv using (column("Size")):(column("Icnt/iter")) \
     title new_qemu." large vector" with lines ls 106

set title "scalar QEMU instruction timings"
set yrange [0:scalar_nspi_range]
set ylabel "ns/instr"
plot old_scalar_csv using (column("Size")):(column("ns/inst")) \
     title old_qemu with lines ls 101, \
     new_scalar_csv using (column("Size")):(column("ns/inst")) \
     title new_qemu with lines ls 102

set title "VLEN=128, LMUL=1 (small vector) QEMU instruction timings"
set yrange [0:small_vector_nspi_range]
set ylabel "ns/instr"
plot old_small_vector_csv using (column("Size")):(column("ns/inst")) \
     title old_qemu with lines ls 101, \
     new_small_vector_csv using (column("Size")):(column("ns/inst")) \
     title new_qemu with lines ls 102

set title "VLEN=1024, LMUL=8 (large vector) QEMU instruction timings"
set yrange [0:large_vector_nspi_range]
set ylabel "ns/instr"
plot old_large_vector_csv using (column("Size")):(column("ns/inst")) \
     title old_qemu with lines ls 101, \
     new_large_vector_csv using (column("Size")):(column("ns/inst")) \
     title new_qemu with lines ls 102

unset multiplot
