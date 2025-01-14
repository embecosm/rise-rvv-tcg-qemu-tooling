# Makefile to generate benchmarks for whole word load/store

# Copyright (C) 2025 Embecosm Limited <www.embecosm.com>
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

# Parameters that can be set
LD_CNT ?= 1
ST_CNT ?= 1
LD_LOOP_CNT ?= 1000000
ST_LOOP_CNT ?= 1000000
VLDOP = vl1re8
VSTOP = vs1r

# The tools and their flags
AS=riscv64-unknown-linux-gnu-gcc
ASFLAGS=-march=rv64gcv -DLD_CNT="$(LD_CNT)" -DST_CNT="$(ST_CNT)" \
        -DLD_LOOP_CNT="$(LD_LOOP_CNT)" -DST_LOOP_CNT="$(ST_LOOP_CNT)" \
        -DVLDOP="$(VLDOP)" -DVSTOP="$(VSTOP)"
CFLAGS=-march=rv64gcv -O0
LDFLAGS=-march=rv64gcv -O0

$(VLDOP).exe: template-ld.S
	$(AS) $(ASFLAGS) $^ -o $@

$(VSTOP).exe: template-st.S
	$(AS) $(ASFLAGS) $^ -o $@

.PHONE: clean
clean:
	$(RM) *.exe
