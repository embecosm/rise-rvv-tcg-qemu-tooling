/* Utilities for benchmarks string/memory functions

   Copyright (C) 2024 Embecosm Limited
   Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

   SPDX-License-Identifier: GPL-3.0-or-later */

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

/* Initialize a byte array with random values.

   @param[in] ptr  Pointer to array to initialize
   @param[in] len  Size of array in bytes */
void
mem_init_random (uint8_t *ptr, size_t len)
{
  for (size_t i = 0; i < len; i++)
    ptr[i] = rand () % 256;
}

/* Initialize a byte array with zero values.

   @param[in] ptr  Pointer to array to initialize
   @param[in] len  Size of array in bytes */
void
mem_init_zero (uint8_t *ptr, size_t len)
{
  for (size_t i = 0; i < len; i++)
    ptr[i] = 0;
}

/* Initialize a string with random values.

   These have to be valid non-null characters, i.e. values in the range 1-127.

   @note The array pointed to must be one byte longer than the number of
         characters to accommodate the '\0' at the end.

   @param[in] str  Pointer to string to initialize
   @param[in] len  Length of string in characters */
void
str_init_random (char *str, size_t len)
{
  for (size_t i = 0; i < len; i++)
    str[i] = rand () % 127 + 1;

  str[len] = '\0';
}

/* Initialize a string with constant values.

   The character should be a valid character, i.e. in the range 1-127, but
   this is not checked.

   @note The array pointed to must be one byte longer than the number of
         characters to accommodate the '\0' at the end.

   @param[in] str  Pointer to string to initialize
   @param[in] len  Length of string in characters
   @param[in] c    The character to initialize with. */
void
str_init_const (char *str, size_t len, const char c)
{
  for (size_t i = 0; i < len; i++)
    str[i] = c;

  str[len] = '\0';
}
