/* Wrapper for benchmarking memchr

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
extern void *memchr_v (const void *s, int c, size_t n);
#endif

#include "benchmark-support.h"

/* The data block to scan */
static uint8_t *data;

/* The results of scanning */
static uint8_t *res[256];

/* Benchmark memchr

   For this function, the size is the size of the block of memory to be
   scanned.  We scan for all 256 possible char values.

   @param[in] size  Size of the benchmark to run
   @param[in] iters number of iterations.
*/

void
benchmark_wrapper (size_t size, size_t iters)
{
  /* Initialize */
  data = malloc (size);
  mem_init_random (data, size);

  /* Benchmark */
  for (size_t i = 0; i < iters; i++)
    for (int c = 0; c < 256; c++)
#ifdef STANDARD_LIB
      res[c] = memchr((const void *) data, c, size);
#else
      res[c] = memchr_v((const void *) data, c, size);
#endif
}

#ifdef VERIF
/* Validate memchr

   We just check that the char pointed to be each of the res entries is
   appropriate.  So not a comprehensive test.

   @param[in] size  Size of the benchmark to run
   @param[in] iters number of iterations (unused).
*/

bool
benchmark_verify (size_t size, size_t iters)
{
  for (int c = 0; c < 256; c++)
    if (res[c] != NULL)
      if (*(res[c]) != (uint8_t)c)
	return false;

  return true;
}
#endif
