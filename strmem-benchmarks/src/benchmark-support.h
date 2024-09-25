/* Header for utilities for benchmarks string/memory functions.

   Copyright (C) 2024 Embecosm Limited
   Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

   SPDX-License-Identifier: GPL-3.0-or-later */

#include <stddef.h>
#include <stdint.h>

extern void  mem_init_random (uint8_t *ptr, size_t len);
extern void  mem_init_zero (uint8_t *ptr, size_t len);
