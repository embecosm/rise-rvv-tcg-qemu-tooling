# Run all the whole word load/store benchmarks

# Copyright (C) 2025 Embecosm Limited <www.embecosm.com>
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

ldinstr="vl1re8  \
	 vl1re16 \
	 vl1re32 \
	 vl1re64 \
         vl2re8  \
	 vl2re16 \
	 vl2re32 \
	 vl2re64 \
         vl4re8  \
	 vl4re16 \
	 vl4re32 \
	 vl4re64 \
         vl8re8  \
	 vl8re16 \
	 vl8re32 \
	 vl8re64"

stinstr="vs1r vs2r vs4r vs8r"

vlenlist="128 256 512 1024"

qemubase="6528013b5f"
qemutest="db95037b42"
tmpf=$(mktemp whole-word-load-store-XXXXXX.txt)

ldresf="ldres.csv"
stresf="stres.csv"

NLOOPS=10000000

# All the load instructions
printf "vlen,ldop,u1base,s1base,u2base,s2base,u1test,s1test,u2test,s2test\n" \
    | tee ${ldresf}
for vl in ${vlenlist}
do
    for i in ${ldinstr}
    do
	# Single instr build
	make clean > /dev/null 2>&1
	make LD_CNT=1 LD_LOOP_CNT=${NLOOPS} VLDOP=${i} ${i}.exe \
	     > /dev/null 2>&1
	# Time with base QEMU
	OLDPATH=${PATH}
	PATH=../../install/qemu-${qemubase}-no-plugin/bin:${OLDPATH}
	(time qemu-riscv64 -cpu rv64,v=true,vlen=${vl} ${i}.exe) \
	    > ${tmpf} 2>&1
	u1base=$(sed -n -e 's/user[[:space:]]*0m\(.\+\)s$/\1/p' < ${tmpf})
	s1base=$(sed -n -e 's/sys[[:space:]]*0m\(.\+\)s$/\1/p' < ${tmpf})
	# Time with test QEMU
	PATH=../../install/qemu-${qemutest}-no-plugin/bin:${OLDPATH}
	(time qemu-riscv64 -cpu rv64,v=true,vlen=${vl} ${i}.exe) \
	    > ${tmpf} 2>&1
	u1test=$(sed -n -e 's/user[[:space:]]*0m\(.\+\)s$/\1/p' < ${tmpf})
	s1test=$(sed -n -e 's/sys[[:space:]]*0m\(.\+\)s$/\1/p' < ${tmpf})

	# Multi-instr build
	make clean > /dev/null 2>&1
	make LD_CNT=11 LD_LOOP_CNT=${NLOOPS} VLDOP=${i} ${i}.exe \
	     > /dev/null 2>&1
	# Time with base QEMU
	PATH=../../install/qemu-${qemubase}-no-plugin/bin:${OLDPATH}
	(time qemu-riscv64 -cpu rv64,v=true,vlen=${vl} ${i}.exe) \
	    > ${tmpf} 2>&1
	u2base=$(sed -n -e 's/user[[:space:]]*0m\(.\+\)s$/\1/p' < ${tmpf})
	s2base=$(sed -n -e 's/sys[[:space:]]*0m\(.\+\)s$/\1/p' < ${tmpf})
	# Time with test QEMU
	PATH=../../install/qemu-${qemutest}-no-plugin/bin:${OLDPATH}
	(time qemu-riscv64 -cpu rv64,v=true,vlen=${vl} ${i}.exe) \
	    > ${tmpf} 2>&1
	u2test=$(sed -n -e 's/user[[:space:]]*0m\(.\+\)s$/\1/p' < ${tmpf})
	s2test=$(sed -n -e 's/sys[[:space:]]*0m\(.\+\)s$/\1/p' < ${tmpf})

	# Print out and clean up
	printf "%d,%s,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f\n" ${vl} ${i} \
	       ${u1base} ${s1base} ${u2base} ${s2base} \
	       ${u1test} ${s1test} ${u2test} ${s2test} \
	    | tee -a ${ldresf}
	PATH=${OLDPATH}
    done
done

# All the store instructions
printf "vlen,stop,u1base,s1base,u2base,s2base,u1test,s1test,u2test,s2test\n" \
    | tee ${stresf}
for vl in ${vlenlist}
do
    for i in ${stinstr}
    do
	# Single instr build
	make clean > /dev/null 2>&1
	make ST_CNT=1 ST_LOOP_CNT=${NLOOPS} VSTOP=${i} ${i}.exe > \
	     /dev/null 2>&1
	# Time with base QEMU
	OLDPATH=${PATH}
	PATH=../../install/qemu-${qemubase}-no-plugin/bin:${OLDPATH}
	(time qemu-riscv64 -cpu rv64,v=true,vlen=${vl} ${i}.exe) \
	    > ${tmpf} 2>&1
	u1base=$(sed -n -e 's/user[[:space:]]*0m\(.\+\)s$/\1/p' < ${tmpf})
	s1base=$(sed -n -e 's/sys[[:space:]]*0m\(.\+\)s$/\1/p' < ${tmpf})
	# Time with test QEMU
	OLDPATH=${PATH}
	PATH=../../install/qemu-${qemutest}-no-plugin/bin:${OLDPATH}
	(time qemu-riscv64 -cpu rv64,v=true,vlen=${vl} ${i}.exe) \
	    > ${tmpf} 2>&1
	u1test=$(sed -n -e 's/user[[:space:]]*0m\(.\+\)s$/\1/p' < ${tmpf})
	s1test=$(sed -n -e 's/sys[[:space:]]*0m\(.\+\)s$/\1/p' < ${tmpf})

	# Multi-instr build
	make clean > /dev/null 2>&1
	make ST_CNT=11 ST_LOOP_CNT=${NLOOPS} VSTOP=${i} ${i}.exe \
	     > /dev/null 2>&1
	# Time with base QEMU
	PATH=../../install/qemu-${qemubase}-no-plugin/bin:${OLDPATH}
	(time qemu-riscv64 -cpu rv64,v=true,vlen=${vl} ${i}.exe) \
	    > ${tmpf} 2>&1
	u2base=$(sed -n -e 's/user[[:space:]]*0m\(.\+\)s$/\1/p' < ${tmpf})
	s2base=$(sed -n -e 's/sys[[:space:]]*0m\(.\+\)s$/\1/p' < ${tmpf})
	# Time with test QEMU
	PATH=../../install/qemu-${qemutest}-no-plugin/bin:${OLDPATH}
	(time qemu-riscv64 -cpu rv64,v=true,vlen=${vl} ${i}.exe) \
	    > ${tmpf} 2>&1
	u2test=$(sed -n -e 's/user[[:space:]]*0m\(.\+\)s$/\1/p' < ${tmpf})
	s2test=$(sed -n -e 's/sys[[:space:]]*0m\(.\+\)s$/\1/p' < ${tmpf})

	# Print out and clean up
	printf "%d,%s,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f\n" ${vl} ${i} \
	       ${u1base} ${s1base} ${u2base} ${s2base} \
	       ${u1test} ${s1test} ${u2test} ${s2test} \
	    | tee -a ${stresf}
	PATH=${OLDPATH}
    done
done

# Tidy up
make clean > /dev/null 2>&1
rm -f ${tmpf}
