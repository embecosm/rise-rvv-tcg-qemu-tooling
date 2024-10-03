/* Wrapper for benchmarking strncpy

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
extern int strncpy_v (char *restrict dst, const char *restrict src,
		      size_t dsize);
#endif

#include "benchmark-support.h"

/* The data blocks to c */
static char *dst;
static char *src;

/* Benchmark strncpy

   For this function, the size is the size of the blocks of memory to be
   copied.  We always allocate twice as much memory.

   @param[in] size  Size of the benchmark to run
   @param[in] iters number of iterations.
*/

void
benchmark_wrapper (size_t size, size_t iters)
{
  /* Initialize */
  dst = malloc (size + size + 1);
  src = malloc (size + size + 1);
  str_init_const (dst, size + size, '@');
  str_init_random (src, size + size);

  /* Benchmark */
  for (size_t i = 0; i < iters; i++)
    {
#ifdef STANDARD_LIB
      strncpy(dst, src, size);
#else
      strncpy_v(dst, src, size);
#endif
    }
}

#ifdef VERIF
/* Validate strncpy

   We check source and destination match manually (which will be from the last
   iterations to compute that dataset).

   @param[in] size  Size of the benchmark to run
   @param[in] iters number of iterations (unused).
*/

bool
benchmark_verify (size_t size, size_t iters)
{
  /* Compare all the characters */
  for (size_t i = 0; i < size; i++)
    if (dst[i] != src[i])
      return false;

  /* Check there is a '\0' at the end of the dst string. */
  if (dst[size] != '\0')
    return false;

  return true;
}
#endif
