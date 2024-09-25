/* Generic main program for benchmarking string/memory functions.

   Copyright (C) 2024 Embecosm Limited
   Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

   SPDX-License-Identifier: GPL-3.0-or-later */

#ifdef VERIF
#include <stdbool.h>
#endif
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>

extern void benchmark_wrapper (size_t size, size_t iters);
#ifdef VERIF
extern bool benchmark_verify (size_t size, size_t iters);
#endif

/* This is the driver for the benchmark programs.  It is supported by
   individual wrappers for specific functions.

   The two mandatory arguments are the "size" of the operaton and the number
   of "iterations".  The "size" parameter is context specific.  For example
   for memcpy it would be size of the block to copy.

   The normal mode of operation is to run a program twice for a given size,
   once with a small number of iterations, once with a large number of
   iterations. The two timings can then be subtracted to give a timing, just
   for the underlying program. This means that any setup code in the wrapper
   must be independent of the number of iterations.

   There is by default no verification.  However if the programs are built
   with -DVERIF, then verification code will be compiled in.

   @param[in] argc  Number of arguments.
   @param[in] argv  Vector of arguments. */

int
main (int argc, char* argv[])
{
  size_t size;
  size_t iters;

  if (argc != 3)
    {
      printf ("Usage: benchmark_main <size> <iterations>\n");
      exit (1);
    }
  else
    {
      size = (size_t) strtoul(argv[1], NULL, 0);
      iters = (size_t) strtoul(argv[2], NULL, 0);
    }

  benchmark_wrapper (size, iters);

#ifdef VERIF
  if (! benchmark_verify (size, iters))
    {
      printf ("ERROR: Verification failed\n");
      exit (1);
    }
#endif

  exit (0);
}
