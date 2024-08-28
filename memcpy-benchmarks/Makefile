# Makefile to generate memory benchmarks

# Copyright (C) 2024 Embecosm Limited
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

CC=riscv64-unknown-linux-gnu-gcc
LD=riscv64-unknown-linux-gnu-gcc
AS=riscv64-unknown-linux-gnu-gcc
ASFLAGS=-march=rv64gcv
CFLAGS=-march=rv64gcv -O0
LDFLAGS=-march=rv64gcv -O0

.PHONY: all
all: smemcpy.exe vmemcpy1.exe vmemcpy2.exe vmemcpy4.exe vmemcpy8.exe bionic_memcpy1.exe bionic_memcpy2.exe bionic_memcpy4.exe bionic_memcpy8.exe

smemcpy.exe: smemcpy-main.o smemcpy.o
	${LD} ${LDFLAGS}  $^ -o $@

vmemcpy1.exe: vmemcpy-main.o vmemcpy1.o
	${LD} ${LDFLAGS}  $^ -o $@
vmemcpy2.exe: vmemcpy-main.o vmemcpy2.o
	${LD} ${LDFLAGS}  $^ -o $@
vmemcpy4.exe: vmemcpy-main.o vmemcpy4.o
	${LD} ${LDFLAGS}  $^ -o $@
vmemcpy8.exe: vmemcpy-main.o vmemcpy8.o
	${LD} ${LDFLAGS}  $^ -o $@

vmemcpy1.o: vmemcpy.S
	$(AS) ${ASFLAGS} -DLMUL=m1 -c $^ -o $@
vmemcpy2.o: vmemcpy.S
	$(AS) ${ASFLAGS} -DLMUL=m2 -c $^ -o $@
vmemcpy4.o: vmemcpy.S
	$(AS) ${ASFLAGS} -DLMUL=m4 -c $^ -o $@
vmemcpy8.o: vmemcpy.S
	$(AS) ${ASFLAGS} -DLMUL=m8 -c $^ -o $@


bionic_memcpy1.exe: bionic_memcpy-main.o bionic_memcpy1.o
	${LD} ${LDFLAGS} $^ -o $@
bionic_memcpy2.exe: bionic_memcpy-main.o bionic_memcpy2.o
	${LD} ${LDFLAGS}  $^ -o $@
bionic_memcpy4.exe: bionic_memcpy-main.o bionic_memcpy4.o
	${LD} ${LDFLAGS}  $^ -o $@
bionic_memcpy8.exe: bionic_memcpy-main.o bionic_memcpy8.o
	${LD} ${LDFLAGS}  $^ -o $@

bionic_memcpy1.o: bionic_memcpy.S
	$(AS) ${ASFLAGS} -DLMUL=m1 -c $^ -o $@
bionic_memcpy2.o: bionic_memcpy.S
	$(AS) ${ASFLAGS} -DLMUL=m2 -c $^ -o $@
bionic_memcpy4.o: bionic_memcpy.S
	$(AS) ${ASFLAGS} -DLMUL=m4 -c $^ -o $@
bionic_memcpy8.o: bionic_memcpy.S
	$(AS) ${ASFLAGS} -DLMUL=m8 -c $^ -o $@

.PHONY: clean
clean:
	$(RM) *.o *.exe
	$(RM) 1.icount 2.icount smem.check vmem.check
