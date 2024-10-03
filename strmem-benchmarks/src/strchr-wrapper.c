/* Wrapper for benchmarking strchr

   Copyright (C) 2024 Embecosm Limited
   Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

   SPDX-License-Identifier: GPL-3.0-or-later */


#ifdef VERIF
#include <stdbool.h>
#endif

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

#ifdef STANDARD_LIB
#include <string.h>
#else
extern void *strchr_v (const char *s, int c);
#endif

#include "benchmark-support.h"

/* The data block to scan */
static char *data;

/* The results of scanning */
static char *res[127];

/* Benchmark strchr

   For this function, the size is the size of the block of strory to be
   scanned.  We scan for all 127 possible char values.

   @param[in] size  Size of the benchmark to run
   @param[in] iters number of iterations.
*/

void
benchmark_wrapper (size_t size, size_t iters)
{
  /* Initialize */
  data = malloc (size + 1);
  str_init_random (data, size);

  /* Benchmark */
  for (size_t i = 0; i < iters; i++)
    for (int c = 1; c < 128; c++)
#ifdef STANDARD_LIB
      res[c - 1] = strchr(data, c);
#else
      res[c - 1] = strchr_v(data, c);
#endif
}

#ifdef VERIF
/* Validate strchr

   We just check that the char pointed to be each of the res entries is
   appropriate.  So not a comprehensive test.

   @param[in] size  Size of the benchmark to run
   @param[in] iters number of iterations (unused).
*/

bool
benchmark_verify (size_t size, size_t iters)
{
  for (int c = 1; c < 128; c++)
    if (res[c - 1] != NULL)
      if (*(res[c - 1]) != (char) c)
	return false;

  return true;
}
#endif
