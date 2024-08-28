/* RISC-V vector memcpy

   Copyright (C) 2020, 2021 RISC-V International

   SPDX-License-Identifier: CC-BY-4.0
*/
#ifndef LMUL
#define LMUL m8
#endif
	.file	"memcpy-vector.S"
	.option arch, +v
	.attribute unaligned_access, 0
	.attribute stack_align, 16
	.text
	.align	1

	// Reference implementation of vector memcpy
	// void *memcpy(void* dest, const void* src, size_t n)
	// a0 = dest, a1 = src, a2 = n
	//
	memcpy:
	.globl	vmemcpy
	.type	vmemcpy, @function
vmemcpy:
	mv	a3, a0			  // Copy destination
loop_cpy:
	vsetvli	t0, a2, e8, LMUL, ta, ma  // Vectors of supplied LMUL
	vle8.v	v0, (a1)		  // Load bytes
	add	a1, a1, t0		  // Bump pointer
	sub	a2, a2, t0		  // Decrement count
	vse8.v	v0, (a3)		  // Store bytes
	add	a3, a3, t0		  // Bump pointer
	bnez	a2, loop_cpy		  // Any more?
	ret
	.size	vmemcpy, .-vmemcpy
