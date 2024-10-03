/* Wrapper for benchmarking strcat

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
extern int strcat_v (char *restrict dest, const char *restrict src);
#endif

#include "benchmark-support.h"

/* The data blocks to c */
static char *dst;
static char *src;
#ifdef VERIF
static char *dst_orig;
#endif

#include <stdio.h>
/* Benchmark strcat

   For this function, the size is the size of the blocks of memory to be
   scanned.  We always compare the entire memory.

   @param[in] size  Size of the benchmark to run
   @param[in] iters number of iterations.
*/

void
benchmark_wrapper (size_t size, size_t iters)
{
  /* Initialize. Note we do manual copying to dst_orig to avoid using the
     very functions we are testing. */
  dst = malloc (size + size + 1);
  src = malloc (size + 1);
  str_init_const (dst, size, '@');
  str_init_random (src, size);

#ifdef VERIF
  dst_orig = malloc (size + size + 1);

  for (size_t i = 0; i < size; i++)
    dst_orig[i] = dst[i];

  dst_orig[size] = '\0';
#endif

  /* Benchmark.  Note that we need to remark the end of the dst string each
     time! */
  for (size_t i = 0; i < iters; i++)
    {
      dst[size] = '\0';
#ifdef STANDARD_LIB
      strcat(dst, src);
#else
      strcat_v(dst, src);
#endif
    }
}

#ifdef VERIF
/* Validate strcat

   We check source and destination match manually (which will be from the last
   iteration to compute that dataset).

   @param[in] size  Size of the benchmark to run
   @param[in] iters number of iterations (unused).
*/

bool
benchmark_verify (size_t size, size_t iters)
{
  /* Original substring, excluding the '\0' should be unchanged. */
  for (size_t i = 0; i < size; i++)
    if (dst[i] != dst_orig[i])
      return false;

  /* Rest of the string, including the '\0' should match the source. */
  for (size_t i = 0; i < (size + 1); i++)
    if (dst[size + i] != src[i])
      return false;

  return true;
}
#endif
