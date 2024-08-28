/* Bionic vector memcpy

   Copyright (C) 2020, 2021 RISC-V International

   Although known as the "bionic" memcpy, this code appears to be almost
   identical to the code in the RISC-V Vector standard.  Copyright attribution
   is therefore given as RISC-V International.

   SPDX-License-Identifier: CC-BY-4.0
*/

# gcc memcpy_test.S -static -ffreestanding -nostartfiles -o memcpy_test
	.file	"test.c"
	.option pic
	.attribute arch, "rv64i2p1_m2p0_a2p1_f2p2_d2p2_c2p0_zicsr2p0_zifencei2p0"
	.attribute unaligned_access, 0
	.attribute stack_align, 16
	.text
	.local	dest
	.comm	dest,65536,8
	.local	src
	.comm	src,65536,8
	.align	1
.type bionic_memcpy, %function
.option arch, +v

#define pDst a0
#define pSrc a1
#define iNum a2

#define iVL a3
#define pDstPtr a4

#define ELEM_LMUL_SETTING m8
#define vData v0

	.globl	bionic_memcpy
	.type	bionic_memcpy, @function
bionic_memcpy:
    mv pDstPtr, pDst

loop:
    vsetvli iVL, iNum, e8, LMUL, ta, ma

    vle8.v vData, (pSrc)
    sub iNum, iNum, iVL
    add pSrc, pSrc, iVL
    vse8.v vData, (pDstPtr)
    add pDstPtr, pDstPtr, iVL

    bnez iNum, loop

    ret

	.section	.note.GNU-stack,"",@progbits
