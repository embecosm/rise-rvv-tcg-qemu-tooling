/* Wrapper for benchmarking memcpy

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
extern int memcpy_v (const void *dest, const void *src, size_t n);
#endif

#include "benchmark-support.h"

/* The data blocks to c */
static uint8_t *dst;
static uint8_t *src;

/* Benchmark memcpy

   For this function, the size is the size of the blocks of memory to be
   scanned.  We always compare the entire memory.

   @param[in] size  Size of the benchmark to run
   @param[in] iters number of iterations.
*/

void
benchmark_wrapper (size_t size, size_t iters)
{
  /* Initialize */
  dst = malloc (size);
  src = malloc (size);
  mem_init_zero (dst, size);
  mem_init_random (src, size);

  /* Benchmark */
  for (size_t i = 0; i < iters; i++)
    {
#ifdef STANDARD_LIB
      memcpy((const void *) dst, (const void *) src, size);
#else
      memcpy_v((const void *) dst, (const void *) src, size);
#endif
    }
}

#ifdef VERIF
/* Validate memcpy

   We check source and destination match manually (which will be from the last
   iterations to compute that dataset).

   @param[in] size  Size of the benchmark to run
   @param[in] iters number of iterations (unused).
*/

bool
benchmark_verify (size_t size, size_t iters)
{
  for (size_t i = 0; i < size; i++)
    if (dst[i] != src[i])
      return false;

  return true;
}
#endif
