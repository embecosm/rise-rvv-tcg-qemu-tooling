# Makefile to generate benchmarks based on SiFive memory/string function
# sources.

# Copyright (C) 2024 Embecosm Limited <www.embecosm.com>
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# Parameters that can be set
SIFIVESRCDIR ?= ../../../sifive-libc/src
BENCHMARK ?= memchr
LMUL ?= 1
EXTRA_DEFS ?= 

# The tools and their flags
AS=riscv64-unknown-linux-gnu-gcc
CC=riscv64-unknown-linux-gnu-gcc
LD=riscv64-unknown-linux-gnu-gcc
ASFLAGS=-march=rv64gcv -DLMUL="m$(LMUL)"
CFLAGS=-march=rv64gcv -O0 $(EXTRA_DEFS)
LDFLAGS=-march=rv64gcv -O0

OBJS = benchmark-main.o benchmark-support.o $(BENCHMARK)-wrapper.o \
       $(BENCHMARK)_vext.o

benchmark-$(BENCHMARK).exe: $(OBJS)
	$(LD) $(LDFLAGS) $^ -o $@

$(BENCHMARK)_vext.S:
	./gensrc.sh --srcdir "$(SIFIVESRCDIR)" --benchmark "$(BENCHMARK)"

.PHONE: clean
clean:
	$(RM) *.S *.o *.exe
