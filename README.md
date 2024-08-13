# Tooling for the RISE RVV QEMU project

A set of convenience scripts for building and benchmarking QEMU for RISC-V
with RVV

## Assumptions

The scripts work on a top level directory structure of
```
- build                      where out-of-tree build artifacts are placed
- install                    where tools etc are installed
- qemu                       the QEMU source tree
- riscv-gnu-toolchain        The RISC-V infrastructure for building tool chains
- rise-rvv-tcg-qemu-tooling  this repository
- speccpu2017                SPEC CPU 2017 source
```

Alongside are the following directories if the compiler tools are being built
```
- binutils                   The binutils-gdb repository
- gcc                        The gcc repository
- gdb                        The binutils-gdb repository
- glibc                      The glibc repository
- linux                      The Linux kernel repository
- llvm-project               The LLVM project repository
```
However it should be noted that most users will not use this, but will instead
use pre-built tool chains. **Note.** There are separate checkouts for the
binutils-gdb repository, to allow different versions for GDB and binutils to
be built.

## Cloning the repos

Initially clone this repository and change into it.  From this directory the
following command will check out the core repositories using the hierarchy
above.
```
./clone-all.sh
```

If you wish to clone all the repositories to use for building tool chains, you
can use:
```
./clone-all.sh --all
```

Don't worry if you already have some repos cloned, they'll just be skipped
with a warning.

Once cloned, the repositories will be checked out to their default branches
for the project.

## Checking out the correct branches/tags

The following convenience script will check out the default tag/branches for
any of the above repositories which have been cloned.
```
./checkout-all.sh
```
An optional argument, `--pull` will pull the repositories after they have been
checked out, but beware of using this if any of the defaults are tags rather
than branches.

For this project, a convenience options `--qemu-checkout <tag>` can be used to
override the default branch used for QEMU.

If you plan to build the tool chains, the default checkouts are for release
tool chains as follows:
- GCC 14.1
- LLVM 18.1.5
- binutils 2.42
- GDB 14.2
- Glibc 2.39

## Adding SPEC CPU 2017

[SPEC CPU 2017](https://www.spec.org/cpu2017/) must be obtained independently
(it is not free).  It should be placed manually in the `specpu2017` directory
at the top level (i.e. as a peer to this directory).

## Building QEMU

QEMU can be built using the `--build-all.sh` script.
```
./build-all.sh --qemu-only
```
**Note.** If you omit the `--qemu-only` argument, the entire tool GCC compiler
tool chain will attempt to be built.

## Building the entire compiler tool chain (optional)

If you wish to build the entire tool chain, this can be achieved with the
`build-all.sh` script:
```
./build-all.sh --qemu-only
```

This will build a GCC tool chain.

The `--build-clang` option will also build a Clang/LLVM tool chain.  The
`--build-gdbserver` option will also build the Linux GDB server program.

Various other options can be used to fine-tune the build.  You can use the
`--help` option to see all these.

## SPEC CPU 2017 benchmarks under QEMU

### Design of the scripts to run SPEC CPU 2017 under QEMU

SPEC CPU 2017 really assumes it is running native.  It is not perfectly set up
for running on a remote target.  We could run QEMU in system mode, but this
would necessitate running all the commands to build the QEMU benchmarks under
QEMU, which would be slow.

So we choose to build the benchmarks on the host machine using the RISC-V
cross-compiler, and then run them under QEMU in application mode. In order to
do this we use the standard standard SPEC CPU 2017 `runcpu` command to build
the benchmarks, with the SPEC CPU `submit` configuration option inserting QEMU
commands for execution.

We then use `runcpu` to perform a _dummy_ run of the benchmarks. With an awk
script, we can then extract the commands to run the benchmarks and check their
results afterwards.  We then run all these scripts in parallel, waiting until
they have all completed.  We use the QEMU `libinsn` plugin to count the number
of instructions executed by each run.  We record statistics of how many
benchmarks built correctly and then ran correctly.

Postprocessing scripts (see below) are then used to extract the results.

### Running the SEPC CPU 2017 benchmarks under QEMU

The script `runspec-qemu.sh` runs the benchmarks.  The most important options
are as follows.

- `--lto` or `--no-lto`. Indicates whether the benchmarks should be built
  using LTO or now.  Default `--no-lto`
- `--vector` or `--no-vector`.  Indicates whether the benchmarks should be
  built for the RISC-V Vector (RVV) extension.  Default `no-vector`.
- `--benchmarks <list>`.  Indicates the set of benchmarks to use.  This can be
  a space separated list of benchmarks, but for convenience the following
  lists are defined:
  - `dummy` - just the four `specrand` benchmarks;
  - `quick` - `602.gcc_s`, `623.xalancbmk_s` and `998.specrand_is`;
  - `intrate` - the SPEC CPU 2017 integer rate benchmarks;
  - `fprate` - the SPEC CPU 2017 floating point rate benchmarks;
  - `intspeed` - the SPEC CPU 2017 integer speed benchmarks;
  - `fpspeed` - the SPEC CPU 2017 floating point speed benchmarks;
  - `rate` - all the SPEC CPU 2017 rate benchmarks;
  - `speed` - all the SPEC CPU 2017 speed benchmarks; and
  - `all` - all the benchmarks.
- `--size test|train|ref`.  The size of datasets to use.  Full runs should use
  the `ref` datasets, but depending on the size of your server can take 2-3 days
  to complete. Most benchmarking for this project uses the `test` datasets.
- `--help`.  Print details of all options to the script.

There are many options to tune SPEC CPU 2017.  However, since the purpose of
this project is to improve QEMU, not tune SPEC CPU 2017, we do not generally
use them.

The script will produce messages as it progresses.  At the end it will report
on how many benchmarks built correctly and how many ran correctly.  Finally it
will print the name of the full log file.  This file will be used later by the
scripts to report metrics.

### Choice of metrics

SPEC CPU 2017 is designed to work with timings, not instruction counts.  To
facilitate the standard scripts, we convert instruction counts to a nominal
time, by treating QEMU as a machine which can execute 10<sup>9</sup>
instructions per second.

But the point of the project is to know how fast QEMU is running.  We time
each benchmark run (some benchmarks have more than one run, using different
datasets).  This is our first QEMU metric.

More usefully we divide this time by the number of instructions executed.
This gives us an average execution time per instruction.  The goal of this
project is to reduce this time, and bring the average time when running with
vector enabled closed to that without vector enabled.

### Scripts to extract results

To get the SPEC CPU 2017 scores, we use the `calc-spec-qemu.sh` script.
```
./calc-spec-qemu.sh --speclog <logfile>
```
where `<logfile>` is the log file reported at the end of the `runspec-qemu.sh`
run. The output is a table with a line for each benchmark showing the official
baseline time (in seconds), the number of QEMU instructions executed, and the
SPEC Ratio, computed on the basis of 10<sup>9</sup> instruction being executed
per second.  There are a number of options to control the format of the output.

- `--md` - produce output as a MarkDown table
- `--csv` - produce output as a CSV file

The default is to produce plain text output.

To get the timing data we use the `dump-qemu-times.sh` script.
```
./dump-qemu-times.sh --speclog <logfile>
```

This will provide a table of real, user and system times for each benchmark.
As with `calc-spec-qemu.sh` scripts, the `--md` and `--csv` options control
output format.  In addition, the `--verbose` option will print additional
tables with a break down of timings for each invididual benchmark run.

### Post processing

At present, post processing is up to the user, typically using a spreadsheet
(CSV output is useful).  When working out QEMU times, we use the sum of user
and system time.  Real time is of less use, since it is too affected by
external factors.

### Sanity checks

When comparing different versions of QEMU, the results from
`calc-spec-qemu.sh` should be the same, or at least very similar. There can be
small variations due to timing differences when interacting with the operating
system, random number generation and the like.

### Known limitations

The script generation from the dummy SPEC CPU 2017 run is not yet perfect.
Some of the scripts used are not to be run on the target platform, but on the
host.  Thus some benchmarks may fail their checks, when in fact they have
executed correctly.  Further work is needed to fix this.
 
