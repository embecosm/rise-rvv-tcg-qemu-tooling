/* Utilities for benchmarks string/memory functions

   Copyright (C) 2024 Embecosm Limited
   Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

   SPDX-License-Identifier: GPL-3.0-or-later */

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

/* Initialize a byte array with random values. */
void
mem_init_random (uint8_t *ptr, size_t len)
{
  for (size_t i = 0; i < len; i++)
    ptr[i] = rand () % 256;
}

/* Initialize a byte array with zero values. */
void
mem_init_zero (uint8_t *ptr, size_t len)
{
  for (size_t i = 0; i < len; i++)
    ptr[i] = 0;
}
