# Memory/String benchmarking

This directory provides scripts to benchmark the SiFive RISC-V Vector (RVV)
assembly language implemenations of standard memory and string functions.  The
functions are:
```
memchr
memcmp
memcpy
memmove
memset
strcat
strchr
strcmp
strcpy
strlen
strncat
strncmp
strncpy
strnlen
```

## Prequisites

To run the benchmarking script you will need:
- Python 3.10 or later
- Gnuplot 5 or later
- Pandoc 2.9 or later
- csvtool (needed for plotting)

## About the benchmarksing

For each benchmarked function, we are comparing a "baseline" QEMU against a
"latest" QEMU.  We look at three versions of the code.

1. the standard library "scalar" implementation of the function
2. the hand-written vector code for VLEN=128 and LMUL=1 ("small vector")
3. the hand-written vector code for VLEN=1024 and LMUL=8 ("large vector")

We thus have a total of 6 datasets.

There are four graphs.  The first looks at the average number of instructions
executed per iteration, and is a sanity check.  Although we plot all 6
datasets, only 3 should show on the graph - the "latest" versions of "scalar",
"small vector" and "large vector", since the version of QEMU should have no
impact on the number of instructions being executed.  This graph is useful to
developers of the vector implementations to see how their code behaves for
different sizes of data, but this is outside the scope of this project.

The remaining three graphs capture QEMU performance for each of the three
versions of the code.  They use the metric of nanoseconds per instruction, to
measure the efficiency of QEMU.  Each graph shows this metric, plotted against
problem size, one line for the "baseline" version of QEMU, the other the
"latest" QEMU.

Ensure a standard GCC 14.1 tool chain is on your path.  You can then run the
benchmarks and generate a PDF report using the following:
```
./run_all_benchmarks.py --qemulist <commit> <commit>
```
Where the arguments are two commits of QEMU you wish to compare, with the
first being presented in the report as the "baseline".  There are numerous
parameters to control the detail of the benchmarking.  Use the `--help` option
to see them.

A full run takes less than 20 minutes to run on a 40 thread AMD Threadripper
1950X at 3.4GHz.  The code is in the `strmem-benchmarks` directory of the
[rise-rvv-tcg-qemu-tooling](https://github.com/embecosm/rise-rvv-tcg-qemu-tooling)
repository.  It is intended to be portable, but to date has only been tested
on Ubuntu 22.04 LTS.
