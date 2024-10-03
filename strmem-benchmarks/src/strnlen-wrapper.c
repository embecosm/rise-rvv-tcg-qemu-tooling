/* Wrapper for benchmarking strnlen

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
extern size_t strnlen_v (const char *s, size_t maxlen);
#endif

#include "benchmark-support.h"

#define DATASETS 256

/* The data blocks to scan */
static char *data[DATASETS];

/* The results of scanning */
static size_t res[DATASETS];

/* Benchmark strnlen

   For this function, the size is the size of the block of string to be
   scanned.  We use up to 256 different datasets and allocate twice as long a
   strint as the size.

   @param[in] size  Size of the benchmark to run
   @param[in] iters number of iterations.
*/

void
benchmark_wrapper (size_t size, size_t iters)
{
  /* Initialize */
  for (size_t i = 0; i < DATASETS; i++)
    {
      data[i] = malloc (size + size + 1);
      str_init_random (data[i], size + size);
    }

  /* Benchmark */
  for (size_t i = 0; i < iters; i++)
    {
      size_t ds = i % DATASETS;
#ifdef STANDARD_LIB
      res[ds] = strnlen(data[ds], size);
#else
      res[ds] = strnlen_v(data[ds], size);
#endif
    }
}

#ifdef VERIF
/* Validate strnlen

   We check the string length manually. It should always be size.

   @param[in] size  Size of the benchmark to run
   @param[in] iters number of iterations (unused).
*/

bool
benchmark_verify (size_t size, size_t iters)
{
  for (size_t nds = 0; nds < MIN(DATASETS, iters); nds++)
    if (res[nds] != size)
      return false;

  return true;
}
#endif
