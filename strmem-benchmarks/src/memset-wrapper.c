/* Wrapper for benchmarking memset

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
extern int memset_v (const void *s1, int c, size_t n);
#endif

#include "benchmark-support.h"

/* We use multiple datasets to try to even out results */
#define DATASETS  256

/* The data blocks to compare */
static uint8_t *data[DATASETS];

/* Benchmark memset

   For this function, the size is the size of the blocks of memory to be
   scanned.  We always compare the entire memory.

   @param[in] size  Size of the benchmark to run
   @param[in] iters number of iterations.
*/

void
benchmark_wrapper (size_t size, size_t iters)
{
  /* Initialize */
  for (size_t i = 0; i < DATASETS; i++)
    {
      data[i] = malloc (size);
      mem_init_random (data[i], size);
    }

  /* Benchmark */
  for (size_t i = 0; i < iters; i++)
    {
      size_t ds = i % DATASETS;
#ifdef STANDARD_LIB
      memset((const void *) data[ds], (int) ds, size);
#else
      memset_v((const void *) data[ds], (int) ds, size);
#endif
    }
}

#ifdef VERIF
/* Validate memset

   We compute the result manually (which will be from the last iterations to
   compute that dataset) and check it is what we expect.

   @note For maximum verification, you should have at least @p DATASET
         iterations.

   @param[in] size  Size of the benchmark to run
   @param[in] iters number of iterations (unused).
*/

bool
benchmark_verify (size_t size, size_t iters)
{
  size_t nds = MIN (DATASETS, iters);
  for (size_t ds = 0; ds < nds; ds++)
    for (size_t i = 0; i < size; i++)
      if (data[ds][i] != ds)
	return false;

  return true;
}
#endif
