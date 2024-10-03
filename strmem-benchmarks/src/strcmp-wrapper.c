/* Wrapper for benchmarking strcmp

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
extern int strcmp_v (const char *s1, const char *s2);
#endif

#include "benchmark-support.h"

/* We use multiple datasets to try to even out results */
#define DATASETS  127

/* The data blocks to compare */
static char *data1[DATASETS];
static char *data2[DATASETS];

/* The result of comparison */
static int res[DATASETS];

/* Benchmark strcmp

   For this function, the size is the size of the blocks of memory to be
   scanned.  We always compare the entire strory.

   @param[in] size  Size of the benchmark to run
   @param[in] iters number of iterations.
*/

void
benchmark_wrapper (size_t size, size_t iters)
{
  /* Initialize */
  for (size_t i = 0; i < DATASETS; i++)
    {
      data1[i] = malloc (size + 1);
      data2[i] = malloc (size + 1);
      str_init_random (data1[i], size);
      str_init_random (data2[i], size);
    }

  /* Benchmark */
  for (size_t i = 0; i < iters; i++)
    {
      size_t ds = i % DATASETS;
#ifdef STANDARD_LIB
      res[ds] = strcmp (data1[ds], data2[ds]);
#else
      res[ds] = strcmp_v (data1[ds], data2[ds]);
#endif
    }
}

#ifdef VERIF
/* Validate strcmp

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
