# Memcpy benchmarks

These programs and scripts allow measurement of QEMU performance with
different `memcpy` implementations.  The programs can be run with a variety of
LMUL and VLEN values and various data block sizes.  We provide three `memcpy`
implementations.

- "Scalar" `memcpy`, taken from Newlib
- "Vector" `memcpy`, taken from the RISC-V Vector standard
- "Bionic" `memcpy`, almost identical to the "Vector" `memcpy`.

# Building the code

Build the code wiht `make`. Ensure you have a suitable RISC-V GCC on your
path.
```
make
```

## Benchmarking

The general principle is to run each benchmark with a large number of
iterations of `memcpy` and then with a small number or iterations.
Subtracting the two times leaves the time due to just `memcpy`, with all the
checking overhead removed.

The `run-memcpy.sh` script will run a single benchmark.  Use the `--help`
option to see arguments and the comments in the script.

The `run-sequence.sh` script will run a large number of benchmarks for
different values of VLEN and LMUL and for a range of data sizes.  Again use
the `--help` option to see arguments and look at the comments in the script.
