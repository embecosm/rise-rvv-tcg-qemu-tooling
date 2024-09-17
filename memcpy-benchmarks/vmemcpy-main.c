/* Main program for vector memcpy

   Copyright (C) 2024 Embecosm Limited
   Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

   SPDX-License-Identifier: GPL-3.0-or-later
*/

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>

#define WARMUP 10

extern void *vmemcpy(void *__restrict dest, const void *__restrict src,
		     size_t n);

// Initialize memory to random values
static void
mem_init_random (uint8_t *ptr, size_t len)
{
  for (size_t i = 0; i < len; i++)
    ptr[i] = rand () % 256;
}

int
main (int argc, char* argv[])
{
  size_t len = 0;
  size_t iterations = 0;
  char *file_path;
  bool validate = false;

  if (argc >= 3) {
    len = atoi(argv[1]);
    iterations = atoi(argv[2]);
  }

  if (argc == 4) {
    file_path = argv[3];
    validate = true;
  }

  FILE *check_file;
  if (validate)
    check_file = fopen(file_path, "a");

  if (len <= 0) {
    printf("error: Data length <= 0\n");
    return 1;
  }

  uint8_t *src = (uint8_t *) malloc (len);
  uint8_t *dst = (uint8_t *) malloc (len);

  mem_init_random (src, len);

  for (size_t i = 0; i < WARMUP; i++)
    vmemcpy (dst, src, len);

  for (size_t i = 0; i < iterations; i++)
    vmemcpy (dst, src, len);

  int checksum = 0;

  if (validate) {
    for (size_t i = 0; i < len; i++)
      checksum += (dst[i] == src[i]) ? 0 : 1;

    fprintf (check_file, "length: %d, result: %s\n", len, (checksum > 0) ? "FAIL" : "PASS");

    if (checksum > 0) {
      fprintf (check_file, "SRC:");
      for (size_t i = 0; i < len; i++) {
        fprintf (check_file, " %u", src[i]);
      }
      fprintf (check_file, "\nDST:");
      for (size_t i = 0; i < len; i++) {
        fprintf (check_file, " %u", dst[i]);
      }
      fprintf (check_file, "\n");
    }

    fclose(check_file);
  }

  free(src);
  free(dst);

}
