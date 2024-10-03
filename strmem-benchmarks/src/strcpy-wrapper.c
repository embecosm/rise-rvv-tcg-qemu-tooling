/* Wrapper for benchmarking strcpy

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
extern int strcpy_v (char *restrict dst, const char *restrict src);
#endif

#include "benchmark-support.h"

/* The data blocks to c */
static char *dst;
static char *src;

/* Benchmark strcpy

   For this function, the size is the size of the blocks of memory to be
   scanned.  We always compare the entire memory.

   @param[in] size  Size of the benchmark to run
   @param[in] iters number of iterations.
*/

void
benchmark_wrapper (size_t size, size_t iters)
{
  /* Initialize */
  dst = malloc (size + 1);
  src = malloc (size + 1);
  str_init_const (dst, size, '@');
  str_init_random (src, size);

  /* Benchmark */
  for (size_t i = 0; i < iters; i++)
    {
#ifdef STANDARD_LIB
      strcpy(dst, src);
#else
      strcpy_v(dst, src);
#endif
    }
}

#ifdef VERIF
/* Validate strcpy

   We check source and destination match manually (which will be from the last
   iterations to compute that dataset).

   @param[in] size  Size of the benchmark to run
   @param[in] iters number of iterations (unused).
*/

bool
benchmark_verify (size_t size, size_t iters)
{
  /* Remember to compare the closing '\0' */
  for (size_t i = 0; i <= size; i++)
    if (dst[i] != src[i])
      return false;

  return true;
}
#endif
