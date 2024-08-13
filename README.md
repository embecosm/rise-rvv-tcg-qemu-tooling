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
