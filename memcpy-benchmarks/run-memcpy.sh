#!/bin/bash

# Copyright (C) 2024 Embecosm Limited <www.embecosm.com>
# Contributor Paolo Savini <paolo.savini@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

TOPDIR="$(dirname $(dirname $(cd $(dirname $0) && echo $PWD)))"
#QEMUBD="${TOPDIR}/riscv-gnu-toolchain/build-qemu"
QEMUBD="${TOPDIR}/build/qemu"
export PATH="${TOPDIR}/install/bin:$PATH"
export QEMU_LD_PREFIX="${TOPDIR}/install/sysroot"

iterations=1000000
overhead_iter=1000
length=1
vlen=128
lmul=8
print_help=false
debug_mode=false
doscalar=true
format="--md"
smemcpy_check_file="smem.check"
vmemcpy_check_file="vmem.check"

usage () {
    cat <<EOF
Usage ./run-memcpy.sh [--iter] <iterations>    : # iterations of the tests
		      [--len] <length>         : Data length in number of bytes
		      [--vlen] <length>        : RVV VLEN for QEMU
		      [--lmul] <lmul>          : RVV LMUL parameter
		      [--csv | --md]           : Format of table
                      [--scalar | --no-scalar] : Omit scalar runs
                      [--help]                 : Print this message and exit
EOF
}

# Parse command line options
set +u
until
  opt="$1"
  case "${opt}" in
      --iter)
          shift
	  iterations="$1"
	  ;;
      --len)
          shift
	  length="$1"
	  ;;
      --vlen)
          shift
	  vlen="$1"
	  ;;
      --lmul)
          shift
	  lmul="$1"
	  ;;
      --md|--csv)
	  format="$1"
	  ;;
      --scalar)
	  doscalar=true
	  ;;
      --no-scalar)
	  doscalar=false
	  ;;
      --debug)
	  debug_mode=true
	  ;;
      --help)
	  print_help=true
	  ;;
      ?*)
	  echo "Unknown argument '$1'"
	  exit 1
	  ;;
      *)
	  ;;
  esac
[ "x${opt}" = "x" ]
do
  shift
done
set -u

if ${print_help}
then
    usage
    exit 1
fi

qemubuilddir="${TOPDIR}/build/qemu"

if [[ -e "${qemubuilddir}/tests/plugin/libinsn.so" ]]
then
    qemuplugindir="${qemubuilddir}/tests/plugin"
elif [[ -e "${qemubuilddir}/tests/tcg/plugins/libinsn.so" ]]
then
    qemuplugindir="${qemubuilddir}/tests/tcg/plugins"
else
    echo "Cannot find QEMU plugin directory: terminating"
    exit 1
fi

if $debug_mode
then
  echo "Emitting guest code and TCG ops"
  echo ""
  qemu-riscv64 -d in_asm -cpu rv64,v=true,vlen=${vlen} smemcpy.exe $length 1 > output-guest-scalar 2>&1
  qemu-riscv64 -d op -cpu rv64,v=true,vlen=${vlen} smemcpy.exe $length 1 > output-ops-scalar 2>&1
  qemu-riscv64 -d in_asm -cpu rv64,v=true,vlen=${vlen} vmemcpy.exe $length 1 > output-guest-vector 2>&1
  qemu-riscv64 -d op -cpu rv64,v=true,vlen=${vlen} vmemcpy.exe $length 1 > output-ops-vector 2>&1
fi

if $doscalar
then
    # Validation
    echo "VLEN: $vlen, length: $length, LMUL: $lmul, iterations: $iterations" >> $smemcpy_check_file
    qemu-riscv64 -cpu rv64,v=true,vlen=${vlen} smemcpy.exe $length 10 $smemcpy_check_file
    # Scalar run
    run1_res=$(/usr/bin/time qemu-riscv64 -cpu rv64,v=true,vlen=${vlen} --d plugin -plugin ${qemuplugindir}/libinsn.so,inline=on -D 1.icount smemcpy.exe $length $((iterations+overhead_iter)) 2>&1)
    scalar_icount1="$(sed -n -e 's/total insns: //p' < 1.icount)"
    run2_res=$(/usr/bin/time qemu-riscv64 -cpu rv64,v=true,vlen=${vlen} -d plugin -plugin ${qemuplugindir}/libinsn.so,inline=on -D 2.icount smemcpy.exe $length $overhead_iter 2>&1)
    scalar_icount2="$(sed -n -e 's/total insns: //p' < 2.icount)"

    user_time1=$(echo ${run1_res} | sed -e 's/user.*$//')
    user_time2=$(echo ${run2_res} | sed -e 's/user.*$//')
    sys_time1=$(echo ${run1_res} | sed -e 's/^.*user //' -e 's/system.*//')
    sys_time2=$(echo ${run2_res} | sed -e 's/^.*user //' -e 's/system.*//')

    scalar_time=$(echo "print (${user_time1} + ${sys_time1} - ${user_time2} - ${sys_time1})" | python)
    scalar_micount=$(echo "print ((${scalar_icount1} - ${scalar_icount2})/1000000.0)" | python)
    scalar_nspi=$(echo "print (${scalar_time} / ${scalar_micount} * 1000.0 )" | python)
else
    # Empty scalar results
    scalar_time=0
    scalar_micount=0
    scalar_nspi=0
fi

# Vector run with LMUL=1
# Validation
echo "VLEN: $vlen, length: $length, LMUL: 1, iterations: $iterations" >> $vmemcpy_check_file
qemu-riscv64 -cpu rv64,v=true,vlen=${vlen} vmemcpy1.exe $length 10 $vmemcpy_check_file
run1_res=$(/usr/bin/time qemu-riscv64 -cpu rv64,v=true,vlen=${vlen} -d plugin -plugin ${qemuplugindir}/libinsn.so,inline=on -D 1.icount vmemcpy1.exe $length $((iterations+overhead_iter)) 2>&1)
vector1_icount1="$(sed -n -e 's/total insns: //p' < 1.icount)"
run2_res=$(/usr/bin/time qemu-riscv64 -cpu rv64,v=true,vlen=${vlen} -d plugin -plugin ${qemuplugindir}/libinsn.so,inline=on -D 2.icount vmemcpy1.exe $length $overhead_iter 2>&1)
vector1_icount2="$(sed -n -e 's/total insns: //p' < 2.icount)"

user_time1=$(echo ${run1_res} | sed -e 's/user.*$//')
user_time2=$(echo ${run2_res} | sed -e 's/user.*$//')
sys_time1=$(echo ${run1_res} | sed -e 's/^.*user //' -e 's/system.*//')
sys_time2=$(echo ${run2_res} | sed -e 's/^.*user //' -e 's/system.*//')

vector1_time=$(echo "print (${user_time1} + ${sys_time1} - ${user_time2} - ${sys_time1})" | python)
vector1_micount=$(echo "print ((${vector1_icount1} - ${vector1_icount2}) / 1000000.0)" | python)
vector1_nspi=$(echo "print (${vector1_time} / ${vector1_micount} * 1000.0 )" | python)

if [[ $lmul != "1" ]]
then
  # Validation
  echo "VLEN: $vlen, length: $length, LMUL: $lmul, iterations: $iterations" >> $vmemcpy_check_file
  qemu-riscv64 -cpu rv64,v=true,vlen=${vlen} vmemcpy$lmul.exe $length 10 $vmemcpy_check_file
  # Vector run with LMUL=lmul
  run1_res=$(/usr/bin/time qemu-riscv64 -cpu rv64,v=true,vlen=${vlen} -d plugin -plugin ${qemuplugindir}/libinsn.so,inline=on -D 1.icount vmemcpy$lmul.exe $length $((iterations+overhead_iter)) 2>&1)
  vectorM_icount1="$(sed -n -e 's/total insns: //p' < 1.icount)"
  run2_res=$(/usr/bin/time qemu-riscv64 -cpu rv64,v=true,vlen=${vlen} -d plugin -plugin ${qemuplugindir}/libinsn.so,inline=on -D 2.icount vmemcpy$lmul.exe $length $overhead_iter 2>&1)
  vectorM_icount2="$(sed -n -e 's/total insns: //p' < 2.icount)"

  user_time1=$(echo ${run1_res} | sed -e 's/user.*$//')
  user_time2=$(echo ${run2_res} | sed -e 's/user.*$//')
  sys_time1=$(echo ${run1_res} | sed -e 's/^.*user //' -e 's/system.*//')
  sys_time2=$(echo ${run2_res} | sed -e 's/^.*user //' -e 's/system.*//')

  vectorM_time=$(echo "print (${user_time1} + ${sys_time1} - ${user_time2} - ${sys_time1})" | python)
  vectorM_micount=$(echo "print ((${vectorM_icount1} - ${vectorM_icount2}) / 1000000.0)" | python)
  vectorM_nspi=$(echo "print (${vectorM_time} / ${vectorM_micount} * 1000.0 )" | python)
fi

if [[ $lmul != "1" ]]
then
  if [[ ${format} == "--md" ]]
  then
      printf "| %10d | %5d | %6d | %7.2f | %7.2f | %7.2f | %10.1f | %10.1f | %10.1f | %10.2f | %10.2f | %10.2f |\n" \
	     ${iterations} ${vlen} $length $scalar_time $vector1_time \
	     $vectorM_time ${scalar_micount} ${vector1_micount} \
	     ${vectorM_micount} ${scalar_nspi} ${vector1_nspi} ${vectorM_nspi}
  else
      printf "\"%d\",\"%d\",\"%d\",\"%.2f\",\"%.2f\",\"%.2f\",\"%.1f\",\"%.1f\",\"%.1f\",\"%.2f\",\"%.2f\",\"%.2f\"\n" \
	     ${iterations} ${vlen} $length $scalar_time $vector1_time \
	     $vectorM_time ${scalar_micount} ${vector1_micount} \
             ${vectorM_micount} ${scalar_nspi} ${vector1_nspi} ${vectorM_nspi}
  fi
else
  if [[ ${format} == "--md" ]]
  then
      printf "| %10d | %5d | %6d | %7.2f | %7.2f | %10.1f | %10.1f | %10.2f | %10.2f |\n" \
	   ${iterations} ${vlen} $length $scalar_time $vector1_time \
	   ${scalar_micount} ${vector1_micount} \
	   ${scalar_nspi} ${vector1_nspi}
  else
      printf "\"%d\",\"%d\",\"%d\",\"%.2f\",\"%.2f\",\"%.1f\",\"%.1f\",\"%.2f\",\"%.2f\"\n" \
	   ${iterations} ${vlen} $length $scalar_time $vector1_time \
	   ${scalar_micount} ${vector1_micount} \
	   ${scalar_nspi} ${vector1_nspi}
  fi
fi

# cleanup
rm -f smemcpy_check_file vmem.check
rm -f 1.icount 2.icount
