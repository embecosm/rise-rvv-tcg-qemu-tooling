/* Wrapper for benchmarking strlen

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
extern size_t strlen_v (const char *s);
#endif

#include "benchmark-support.h"

#define DATASETS 256

/* The data blocks to scan */
static char *data[DATASETS];

/* The results of scanning */
static size_t res[DATASETS];

/* Benchmark strlen

   For this function, the size is the size of the block of string to be
   scanned.  We use up to 256 different datasets.

   @param[in] size  Size of the benchmark to run
   @param[in] iters number of iterations.
*/

void
benchmark_wrapper (size_t size, size_t iters)
{
  /* Initialize */
  for (size_t i = 0; i < DATASETS; i++)
    {
      data[i] = malloc (size + 1);
      str_init_random (data[i], size);
    }

  /* Benchmark */
  for (size_t i = 0; i < iters; i++)
    {
      size_t ds = i % DATASETS;
#ifdef STANDARD_LIB
      res[ds] = strlen(data[ds]);
#else
      res[ds] = strlen_v(data[ds]);
#endif
    }
}

#ifdef VERIF
/* Validate strlen

   We check the string length manually.

   @param[in] size  Size of the benchmark to run
   @param[in] iters number of iterations (unused).
*/

bool
benchmark_verify (size_t size, size_t iters)
{
  for (size_t nds = 0; nds < MIN(DATASETS, iters); nds++)
    {
      int hand_size = 0;

      while (data[nds][hand_size] != '\0')
	hand_size++;

      if (res[nds] != hand_size)
	return false;
    }

  return true;
}
#endif
