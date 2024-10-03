/* Wrapper for benchmarking memcmp

   Copyright (C) 2024 Embecosm Limited
   Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

   SPDX-License-Identifier: GPL-3.0-or-later */


#ifdef VERIF
#include <stdbool.h>
#endif

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <sys/param.h>

#ifdef STANDARD_LIB
#include <string.h>
#else
extern int memcmp_v (const void *s1, const void *s2, size_t n);
#endif

#include "benchmark-support.h"

/* We use multiple datasets to try to even out results */
#define DATASETS  256

/* The data blocks to compare */
static uint8_t *data1[DATASETS];
static uint8_t *data2[DATASETS];

/* The result of comparison */
static int res[DATASETS];

/* Benchmark memcmp

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
      data1[i] = malloc (size);
      data2[i] = malloc (size);
      mem_init_random (data1[i], size);
      mem_init_random (data2[i], size);
    }

  /* Benchmark */
  for (size_t i = 0; i < iters; i++)
    {
      size_t ds = i % DATASETS;
#ifdef STANDARD_LIB
      res[ds] = memcmp ((const void *) data1[ds], (const void *) data2[ds],
		       size);
#else
      res[ds] = memcmp_v ((const void *) data1[ds], (const void *) data2[ds],
			  size);
#endif
    }
}

#ifdef VERIF
/* Validate memcmp

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
    {
      int r;

      for (size_t i = 0; i < size; i++)
	{
	  r = data1[ds][i] - data2[ds][i];
	  if (r != 0)
	    break;
	}

      if (r != res[ds])
	return false;
    }

  return true;
}
#endif
