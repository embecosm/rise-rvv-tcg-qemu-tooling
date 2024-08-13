#!/bin/bash

# Script to run SPEC CPU 2017 on QEMU

# Copyright (C) 2009, 2013, 2014, 2015, 2016, 2017, 2022, 2023, 2024 Embecosm Limited
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# This file is part of the Embecosm GNU toolchain build system for RISC-V.

# SPDX-License-Identifier: GPL-3.0-or-later

# Usage
#
#   runspec-qemu.sh <SPEC installed dir>
#

set -u

# Useful functions

# Duplicate a string
# - $1: String to duplicate
# - $2: How often to duplicate
dup () {
    printf "$1%.0s" $(seq 1 $2)
}

# Print out a heading to log only
# - $1: Heading
loghdr () {
    echo "" >> ${logfile}
    echo "$1" >> ${logfile}
    echo "$(dup = ${#1})" >> ${logfile}
}

# Print out a heading to log and to screen
# - $1: Heading
# - $2: Optional elipsis for screen only
hdr () {
    if [[ $# -eq 2 ]]
    then
	echo "$1$2"
    else
	echo "$1"
    fi
    echo "" >> ${logfile}
    echo "$1" >> ${logfile}
    echo "$(dup = ${#1})" >> ${logfile}
}

# Print a message to log only
# - $1: Heading
logmess () {
    echo "$1" >> ${logfile}
}

# Print a message to log and to screen
# - $1: Heading
# - $2: Optional elipsis for screen only
mess () {
    if [[ $# -eq 2 ]]
    then
	echo "$1$2"
    else
	echo "$1"
    fi
    echo "$1" >> ${logfile}
}

# Print a time-stamped message to log only
# - $1: Heading
logtmess () {
    ts="$(date +\"%Y-%m-%d-%H:%M:%S\"):"
    echo "${ts} $1" >> ${logfile}
}

# Print a time-stamped message to log and to screen
# - $1: Heading
# - $2: Optional elipsis for screen only
tmess () {
    ts="$(date +\"%Y-%m-%d-%H:%M:%S\"):"
    if [[ $# -eq 2 ]]
    then
	echo "${ts} $1$2"
    else
	echo "${ts} $1"
    fi
    echo "${ts} $1" >> ${logfile}
}

# Print out the help message
dohelp () {
    cat <<EOF
Usage: runspec-qemu.sh [--tooldir <dir>]
                       [--toolbindir <dir>]
                       [--topdir <dir>]
                       [--installdir <dir>]
                       [--specsrcdir <dir>]
                       [--specdir <dir>]
                       [--builddir <dir>]
                       [--logdir <dir>]
                       [--cc gcc | clang]
                       [--cxx g++ | clang++]
                       [--fc gfortran | flang]
                       [--benchmarks <benchmark_list>]
                       [--size test|train|ref]
                       [--tune base|peak|all]
                       [--config <confname>]
                       [--march]
                       [--mabi]
                       [--lto]
                       [--no-lto]
                       [--vector]
                       [--no-vector]
                       [--spec-flags <str>]
                       [--qemu64-flags <str>]
                       [--keeptmp]
                       [--clean]
                       [--build-only]
		       [--static]
                       [--help|-h]

The benchmark list may include the shorthands quick, intrate, fprate,
intspeed, fpspeed, rate, speed, all.  Otherwise it is a space separated
list of benchmark names.

--march        defaults to "rv64gc"
--mabi         defaults to "lp64d",
--spec-flags   the base list of flags to use for all SPEC runs, which defaults
               to "-Ofast".  The LTO and vector flags are appended to this.
--cc/-cxx/-fc  compilers default to gcc, g++ and gfortran
--[no-]lto     remove/add "-flto=auto" to the SPEC flags, defaults to --no-lto.
--[no-]vector  shorthand for "--march rv64gcv -mabi lp64d". Defaults to --no-vector.
--qemu64-flags the list of supplementary QEMU CPU flags, defaults to
               "zicsr=true,v=true,vext_spec=v1.0,zfh=true,zvfh=true"

For other vectorization behavior, the --spec-flags will need to be set explicitly. for example to set a fixed maximum VLEN, use

    ".. --param=riscv-autovec-preference=fixed-vlmax"

If wished, the value of LMUL may be set to "m2", "m4" or "m8" using

    --param=riscv-autovec-lmul=<val>"
EOF
}

# Set up directories
rundate="$(date +%Y-%m-%d-%H-%M-%S)"
topdir="$(dirname $(cd $(dirname $0) && echo ${PWD}))"
tooldir="${topdir}/rise-rvv-tcg-qemu-tooling"
toolbindir="${topdir}/install"
installdir="${topdir}/install"
specsrcdir="${topdir}/speccpu2017"
builddir="${topdir}/build"
qemubuilddir="${topdir}/build/qemu"
logdir="${topdir}/logs"
specdir=""

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

# Common SPEC shorthand
spec_dummy="996.specrand_fs 997.specrand_fr 998.specrand_is 999.specrand_ir"
spec_quick="602.gcc_s 623.xalancbmk_s 998.specrand_is"
spec_intrate="500.perlbench_r 502.gcc_r 505.mcf_r 520.omnetpp_r 523.xalancbmk_r 525.x264_r 531.deepsjeng_r 541.leela_r 548.exchange2_r 557.xz_r 999.specrand_ir"
spec_fprate="503.bwaves_r 507.cactuBSSN_r 508.namd_r 510.parest_r 511.povray_r 519.lbm_r 521.wrf_r 526.blender_r 527.cam4_r 538.imagick_r 544.nab_r 549.fotonik3d_r 554.roms_r 997.specrand_fr"
spec_intspeed="600.perlbench_s 602.gcc_s 605.mcf_s 620.omnetpp_s 623.xalancbmk_s 625.x264_s 631.deepsjeng_s 641.leela_s 648.exchange2_s 657.xz_s 998.specrand_is"
spec_fpspeed="603.bwaves_s 607.cactuBSSN_s 619.lbm_s 621.wrf_s 627.cam4_s 628.pop2_s 638.imagick_s 644.nab_s 649.fotonik3d_s 654.roms_s 996.specrand_fs"
spec_rate="${spec_intrate} ${spec_fprate}"
spec_speed="${spec_intspeed} ${spec_fpspeed}"
spec_all="${spec_rate} ${spec_speed}"

# Set up default script parameters
benchmarks="${spec_intspeed}"
config="linux-riscv64-qemu"
size="ref"
tune="base"
arch="rv64gc"
abi="lp64d"
spec_flags="-Ofast"
lto_flags=""
vector_flags=""
static_flags=""
cc_compiler="gcc"
cxx_compiler="g++"
fc_compiler="gfortran"

# May need to change this for other supported extensions
qemu64_flags="zicsr=true,v=true,vext_spec=v1.0,zfh=true,zvfh=true"
keeptmp=""
doclean="no"
dorun="yes"
logfile="spec-qemu-${rundate}"

# Parse command line options
set +u
until
    opt="$1"
    case "${opt}"
    in
	--specsrcdir)
	    shift
	    specsrcdir="$1"
	    ;;
	--specdir)
	    shift
	    specdir="$1"
	    ;;
	--tooldir)
	    shift
	    tooldir="$1"
	    ;;
	--toolbindir)
	    shift
	    toolbindir="$1"
	    ;;
	--installdir)
	    shift
	    installdir="$1"
	    ;;
	--builddir)
	    shift
	    builddir="$1"
	    ;;
	--logdir)
	    shift
	    logdir="$1"
	    ;;
	--benchmarks)
	    shift
	    case "$1"
	    in
		dummy)
		    benchmarks="${spec_dummy}"
		    ;;
		quick)
		    benchmarks="${spec_quick}"
		    ;;
		intrate)
		    benchmarks="${spec_intrate}"
		    ;;
		fprate)
		    benchmarks="${spec_fprate}"
		    ;;
		intspeed)
		    benchmarks="${spec_intspeed}"
		    ;;
		fpspeed)
		    benchmarks="${spec_fpspeed}"
		    ;;
		rate)
		    benchmarks="${spec_rate}"
		    ;;
		speed)
		    benchmarks="${spec_speed}"
		    ;;
		all)
		    benchmarks="${spec_all}"
		    ;;
		*)
		    benchmarks="$1"
		    ;;
	    esac
	    ;;
	--size)
	    shift
	    case "$1"
	    in
		test|train|ref)
		    size=$1
		    ;;
		*)
		    echo "Unknown size: \"$1\" - ignored."
		    ;;
	    esac
	    ;;
	--tune)
	    shift
	    case "$1"
	    in
		base|peak|all)
		    tune=$1
		    ;;
		*)
		    echo "Unknown tune: \"$1\" - ignored."
		    ;;
	    esac
	    ;;
	--config)
	    shift
	    config=$1
	    ;;
	--march)
	    shift
	    arch="$1"
	    ;;
	--mabi)
	    shift
	    abi="$1"
	    ;;
	--vector)
	    arch="rv64gcv"
	    abi="lp64d"
	    vector_flags=""
	    ;;
	--no-vector)
	    arch="rv64gc"
	    abi="lp64d"
	    vector_flags=""
	    ;;
	--lto)
	    lto_flags="-flto=auto"
	    ;;
	--no-lto)
	    lto_flags=""
	    ;;
	--spec-flags)
	    shift
	    spec_flags="$1"
	    ;;
	--qemu64-flags)
	    shift
	    qemu64_flags="$1"
	    ;;
	--keeptmp)
	    keeptmp="-keeptmp"
	    ;;
	--logfile)
            shift
            logfile="$1"
            ;;
	--clean)
            doclean="yes"
	    ;;
	--build-only)
            dorun="no"
	    ;;
	--static)
	    static_flags="-static -Wl,-Ttext-segment,0x10000"
	    ;;
	--cc)
	    shift
	    case "${1}"
	    in
		gcc|clang)
		    cc_compiler="${1}"
		    ;;
		*)
		    echo "Unknown C compiler \"$1\""
		    dohelp
		    exit 1
		    ;;
	    esac
	    ;;
	--cxx)
	    shift
	    case "${1}"
	    in
		g++|clang++)
		    cxx_compiler="${1}"
		    ;;
		*)
		    echo "Unknown C++ compiler \"$1\""
		    dohelp
		    exit 1
		    ;;
	    esac
	    ;;
	--fc)
	    shift
	    case "${1}"
	    in
		gfortran|flang)
		    fc_compiler="${1}"
		    ;;
		*)
		    echo "Unknown C compiler \"$1\""
		    dohelp
		    exit 1
		    ;;
	    esac
	    ;;

	--help|-h)
	    dohelp
	    exit 0
	    ;;
	?*)
	    echo "Unknown argument '$1'"
	    dohelp
	    exit 1
	    ;;
    esac
    [ "x${opt}" = "x" ]
do
    shift
done
set -u

# Compose the complete spec flags
spec_flags="${spec_flags} ${lto_flags} ${vector_flags}"

# Make exisiting directories absolute, creating those that may not exist first
mkdir -p "${builddir}"
mkdir -p "${logdir}"
topdir="$(cd ${topdir} && echo ${PWD})"
tooldir="$(cd ${tooldir} && echo ${PWD})"
toolbindir="$(cd ${toolbindir} && echo ${PWD})"
installdir="$(cd ${installdir} && echo ${PWD})"
specsrcdir="$(cd ${specsrcdir} && echo ${PWD})"
builddir="$(cd ${builddir} && echo ${PWD})"
logdir="$(cd ${logdir} && echo ${PWD})"

# Set up derived files and directories.  Note that the script directory is
# always cleaned!
logfile="${logdir}/${logfile}.log"
tmpdir=$(mktemp -d -p /tmp spec-qemu-XXXXXX)

if [[ "x${specdir}" == "x" ]]
then
    mkdir -p "${installdir}"
    specdir="${installdir}/spec-${rundate}"
fi

# Timestamp start (has to be after logfile declared)
tmess "Run started, logging to ${logfile}"

# Log all the parameters
echo "Parameters:"                   >> ${logfile}
echo "==========="                   >> ${logfile}
echo "topdir:       ${topdir}"       >> ${logfile}
echo "tooldir:      ${tooldir}"      >> ${logfile}
echo "toolbindir:   ${toolbindir}"   >> ${logfile}
echo "installdir:   ${installdir}"   >> ${logfile}
echo "specdir:      ${specdir}"      >> ${logfile}
echo "specsrcdir:   ${specsrcdir}"   >> ${logfile}
echo "builddir:     ${builddir}"     >> ${logfile}
echo "logdir:       ${logdir}"       >> ${logfile}
echo "logfile:      ${logfile}"      >> ${logfile}
echo "tmpdir:       ${tmpdir}"       >> ${logfile}
echo "benchmarks:   ${benchmarks}"   >> ${logfile}
echo "size:         ${size}"         >> ${logfile}
echo "tune:         ${tune}"         >> ${logfile}
echo "config:       ${config}"       >> ${logfile}
echo "arch          ${arch}"         >> ${logfile}
echo "abi           ${abi}"          >> ${logfile}
echo "spec_flags:   ${spec_flags}"   >> ${logfile}
echo "qemu64_flags: ${qemu64_flags}" >> ${logfile}
echo "static_flags: ${static_flags}" >> ${logfile}
echo "cc_compiler:  ${cc_compiler}"  >> ${logfile}
echo "cxx_compiler: ${cxx_compiler}" >> ${logfile}
echo "fc_compiler:  ${fc_compiler}"  >> ${logfile}
echo "keeptmp:      ${keeptmp}"      >> ${logfile}
echo "doclean:      ${doclean}"      >> ${logfile}
echo "dorun:        ${dorun}"        >> ${logfile}

# Install SPEC CPU 2017 if desired
if [[ -d ${specdir} ]]
then
    mess "SPEC CPU 2017 already installed in ${specdir}"
else
    hdr "Installing SPEC CPU 2017" "..."
    cd ${specsrcdir}
    if ./install.sh -f -d ${specdir} >> ${logfile} 2>&1
    then
	mess "SPEC CPU 2017 installed in ${specdir}"
    else
	mess "ERROR: failed to install SPEC CPU 2017"
	mess "See ${logfile}"
	exit 1
    fi
fi

# Make the SPEC directory abolute (can only do after installation)
specdir="$(cd ${specdir} && echo ${PWD})"

# Set up the script directory and ensure it is clean (only possible after
# installation).
scriptdir="${specdir}/scripts"
rm -rf ${scriptdir}
mkdir -p ${scriptdir}

# Set up SPEC CPU environment
cat ${tooldir}/spec-configs/${config}.cfg \
    ${tooldir}/spec-configs/peak-flags-qemu.cfg \
    > ${specdir}/config/${config}.cfg
cd ${specdir}
source shrc
export PATH=${toolbindir}/bin:$PATH
export QEMU_LD_PREFIX=${toolbindir}/sysroot

# Clean the installation
cleanlog=
if [[ "${doclean}" == "yes" ]]
then
    hdr "Cleaning" "..."

    runcpu --config ${config} --define gcc_dir=${installdir} \
	   --define qemu_plugin_dir=${qemuplugindir} \
	   --define build_ncpus=$(nproc) \
	   --define model="-march=${arch} -mabi=${abi}" \
	   --define spec_flags="${spec_flags}" \
	   --define qemu64_flags="${qemu64_flags}" \
	   --define static_flags="${static_flags}" \
	   --define cc_compiler="${cc_compiler}" \
	   --define cxx_compiler="${cxx_compiler}" \
	   --define fc_compiler="${fc_compiler}" \
	   --action scrub ${benchmarks} \
	   >> ${tmpdir}/cleaning-log 2>&1
    cat ${tmpdir}/cleaning-log >> ${logfile}
    cleanlog="$(sed -n -e 's/^The log for this run is in \(.*\)$/\1/p' \
                    ${tmpdir}/cleaning-log)"
    rm -f ${tmpdir}/cleaning-log
fi

# Build all the benchmarks and set up execution
hdr "Building" "..."
buildlog=
bd="${tmpdir}/building-log"
runcpu --config ${config} --define gcc_dir=${installdir} \
       --define qemu_plugin_dir=${qemuplugindir} \
       --define build_ncpus=$(nproc) --define use_submit \
       --define model="-march=${arch} -mabi=${abi}" \
       --define spec_flags="${spec_flags}" \
       --define qemu64_flags="${qemu64_flags}" \
       --define static_flags="${static_flags}" \
       --define cc_compiler="${cc_compiler}" \
       --define cxx_compiler="${cxx_compiler}" \
       --define fc_compiler="${fc_compiler}" \
       --tune=${tune} --size=${size} ${keeptmp} \
       --loose --action setup \
       ${benchmarks} >> ${bd} 2>&1
cat ${bd} >> ${logfile}
buildlog="$(sed -n -e 's/^The log for this run is in \(.*\)$/\1/p' ${bd})"
goodbuilds="$(sed -n -e 's/^Build successes for.*: //p' < ${bd} | \
		    sed -e 's/([^)]\+),\?//g' | sed -e 's/ *None *//')"
badbuilds="$(sed -n -e 's/^Build errors for.*: //p' < ${bd} | \
		    sed -e 's/([^)]\+),\?//g' | sed -e 's/ *None *//')"

numgoodbuilds=0
numbadbuilds=0

if [[ "x${goodbuilds}" != "x" ]]
then
    for b in ${goodbuilds}
    do
	numgoodbuilds=$(( numgoodbuilds + 1 ))
    done
fi
if [[ "x${badbuilds}" != "x" ]]
then
    for b in ${badbuilds}
    do
	numbadbuilds=$(( numbadbuilds + 1 ))
    done
fi

rm -f ${bd}

numbad=0
numgood=0

# Only do running if requested
if [[ "x${dorun}" == "xyes" ]]
then
    # Construct scripts to execute each benchmark run (which will include ones
    # which failed to build).
    hdr "Creating scripts" "..."
    declare -A runlog
    for bm in ${benchmarks}
    do
	mess "Creating script to run $bm"
	bmlog="${tmpdir}/$bm.log"
	runcpu --config ${config} --define gcc_dir=${installdir} \
	       --define qemu_plugin_dir=${qemuplugindir} \
	       --define build_ncpus=$(nproc) --define use_submit \
	       --define model="-march=${arch} -mabi=${abi}" \
	       --define spec_flags="${spec_flags}" \
	       --define qemu64_flags="${qemu64_flags}" \
	       --define static_flags="${static_flags}" \
	       --define cc_compiler="${cc_compiler}" \
	       --define cxx_compiler="${cxx_compiler}" \
	       --define fc_compiler="${fc_compiler}" \
	       --tune=${tune} --size=${size} ${keeptmp} \
	       --loose --fake --action run ${bm} > ${bmlog} 2>&1
	runlog["${bm}"]="$(awk -f ${tooldir}/runspec-breakout.awk \
                           ${scriptdir}/${bm} < ${bmlog})"
	cat ${bmlog} >> ${logfile}
    done

    # Now do all the runs together.
    hdr "Launching run scripts" "..."
    numprocs=0
    pidlist=
    loglist=
    for script in ${scriptdir}/*-run-*.sh
    do
	chmod ugo+x ${script}
	bmlog="${tmpdir}/$(basename ${script} | sed -e 's/sh$/log/')"
	if [[ "x${loglist}" == "x" ]]
	then
	    loglist="${bmlog}"
	else
	    loglist="${bmlog} ${loglist}"
	fi
	(time ${script}) > ${bmlog} 2>&1 & pid=$!
	if [[ "x${pidlist}" == "x" ]]
	then
	    pidlist="${pid}"
	else
	    pidlist="${pid},${pidlist}"
	fi
	numprocs=$(( numprocs + 1 ))
    done

    tmess "Launched ${numprocs} run scripts"

    # Wait for them all to complete
    tcheck=0
    while [[ ${numprocs} -ne 0 ]]
    do
	sleep 10
	numprocs=$(ps --no-headers -q ${pidlist} | wc -l)
	if [[ ${numprocs} -eq 0 ]]
	then
	    tmess "All run scripts completed"
	else
	    # Show we are alive every 30 x 10 = 300s
	    tcheck=$(( tcheck + 1 ))
	    if [[ ${tcheck} -eq 30 ]]
	    then
		tmess "${numprocs} run scripts still running" "..."
		tcheck=0
	    fi
	fi
    done

    # Append all the benchmark logs
    hdr "Appending benchmark run logs" "..."
    for bmlog in ${loglist}
    do
	loghdr "Run log for $(basename ${bmlog} | sed -e 's/.log$//')"
	cat ${bmlog} >> ${logfile}
    done

    # Finally check for correctness.  We do this in benchmark order for clarity
    hdr "Checking results" "..."
    numgood=0
    numbad=0
    for bm in ${goodbuilds}
    do
	bmfails=0
	for script in ${scriptdir}/${bm}-check-*.sh
	do
	    chmod ugo+x ${script}
	    if ! ${script} >> ${logfile} 2>&1
	    then
		logmess "${script} failed check"
		bmfails=$(( bmfails + 1 ))
	    fi
	done
	if [[ ${bmfails} -eq 0 ]]
	then
	    numgood=$(( numgood + 1 ))
	else
	    numbad=$(( numbad + 1 ))
	    mess "${bm} failed ${bmfails} checks"
	fi
    done
fi

mess "${numgoodbuilds} benchmarks built correctly, ${numbadbuilds} failed"
if [[ "x${dorun}" == "xyes" ]]
then
    mess "${numgood} benchmark runs passed, ${numbad} failed"
fi

if [[ "${doclean}" == "yes" ]]
then
    logmess "SPEC CPU cleaning log in ${cleanlog}"
fi
logmess "SPEC CPU build log in ${buildlog}"
if [[ "x${dorun}" == "xyes" ]]
then
    for run in ${!runlog[@]}
    do
	logmess "SPEC CPU run log for ${run} in ${runlog[${run}]}"
    done
fi

tmess "Run completed, log in ${logfile}"

# Clean up
rm -rf ${tmpdir}

# Return code is always successful if we get this far, otherwise Jenkins gives
# up.  In a perfect world, we would use the following:
#
#   if [[ ${numbad} -ne 0 || ${numbadbuilds} -ne 0 ]]
#   then
#       exit 1
#   fi

exit 0
