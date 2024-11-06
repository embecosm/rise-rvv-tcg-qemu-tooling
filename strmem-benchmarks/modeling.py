#!/usr/bin/env python3

# The class to do the actual modeling

# Copyright (C) 2024 Embecosm Limited

# Contributor: Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

"""
We create all the models, then run them in parallel and generate CSV files of
the results.
"""

import concurrent.futures
import csv
import os
import os.path
import re
import resource
import shutil
import subprocess
import sys
import tempfile

# What we export

__all__ = [
    'Model',
    'ModelSet',
]

class Model:
    """A class to run a single configuration.

       The configuration is defined by a tuple of the following
       - the QEMU commit being used
       - the benchmark
       - the configuration (VLEN/LMUL or stdlib)

       That configuration is then run as a single job for all the data sizes
       specified.  The point being that the benchmark must be built for the
       configuration and LMUL/stdlib, but the size (and the VLEN if given) is a
       dynamic argument to the program, not requiring a rebuild of the
       benchmark.

       Note however that because we treat QEMU commit and VLEN as part of the
       conf, we potentially may build multiple benchmark identical
       executables, if we have configurations with the same LMUL but different
       VLENs.  We consider this to be mostly not the case, and if it does, the
       time taken to build a configuration is very small, so the duplication
       is not expensive.
    """

    # Tables of baseline iterations
    BASELINE_ITERS = { 'memchr'  :   300000,
                       'memcmp'  :  8000000,
                       'memcpy'  : 10000000,
                       'memmove' : 10000000,
                       'memset'  : 12000000,
                       'strcat'  :  3000000,
                       'strchr'  :    50000,
                       'strcmp'  :  6000000,
                       'strcpy'  :  5000000,
                       'strlen'  :  9000000,
                       'strncat' :  3000000,
                       'strncmp' :  6000000,
                       'strncpy' :  4000000,
                       'strnlen' :  5000000, }
    BASELINE_VERIF_ITERS = { 'memchr'  :   30000,
                             'memcmp'  :  800000,
                             'memcpy'  : 1000000,
                             'memmove' : 1000000,
                             'memset'  : 1200000,
                             'strcat'  :  300000,
                             'strchr'  :    5000,
                             'strcmp'  :  600000,
                             'strcpy'  :  500000,
                             'strlen'  :  900000,
                             'strncat' :  300000,
                             'strncmp' :  600000,
                             'strncpy' :  400000,
                             'strnlen' :  500000, }

    def __init__(self, qb, bm, conf, args, log):
        """Constructor for the builder, which just records the configuration
           and creates the various files and directories."""
        self._qb = qb
        self._cmt = qb.cmt
        self._qemuplugin = qb.qemuplugin
        self._bm = bm
        self._args = args
        self._log = log
        if conf == 'stdlib':
            # We need valid VLEN/LMUL, but they are not actually used.
            self._stdlib = True
            self._vlen = 128
            self._lmul = 1
            self.suffix = self._cmt + '-' + bm + '-' + 'stdlib'
        else:
            self._stdlib = False
            self._vlen, self._lmul = conf.split('-')
            self.suffix = self._cmt + '-' + bm + '-' + self._vlen + \
                '-m' + self._lmul
        self.builddir = os.path.join(args.get('strmemdir'), 'build',
                                     'bd-' + self.suffix)
        self._bmexe = os.path.join(
            self.builddir, 'benchmark-' + self._bm + '.exe')
        self._resdir = self._args.get('resdir')
        self._resfile = os.path.join(self._resdir, self.suffix + '.csv')
        self.buildok = False
        self.results = {}
        self._setup()

    def _setup(self):
        """Ensure we have clean build and results directories for this
           configuration.  Delete the directory and then make a copy of the
           reference source code in the build directory.
        """
        for dirname in [self.builddir, self._resdir]:
            # Delete any existing directory
            self._log.debug(f'DEBUG: Cleaning {self.suffix}')
            try:
                shutil.rmtree(dirname, ignore_errors=True)
            except Exception as e:
                ename=type(e).__name__
                self._log.error(
                    f'ERROR: Clean of {dirname} failed: {ename}.')
                sys.exit(1)

        # Create the build directory.
        refsrc = os.path.join(self._args.get('strmemdir'), 'src')
        try:
            shutil.copytree(refsrc, self.builddir)
        except Exception as e:
            ename=type(e).__name__
            self._log.error(
                f'ERROR: Unable to create {self.builddir}: {ename}')
            sys.exit(1)

        # Create the (empty) results directory
        try:
            os.mkdir(self._resdir)
        except Exception as e:
            ename=type(e).__name__
            self._log.error(
                f'ERROR: Unable to create {self.builddir}: {ename}')
            sys.exit(1)

    def build(self):
        """Build the executables for this configuration.  Return true on
           success."""
        self._log.debug(f'DEBUG: Building {self.suffix}')
        if self._args.get('verify'):
            verify_flag='-DVERIF'
        else:
            verify_flag=''

        sfsrc=self._args.get('sifivesrcdir')
        if self._stdlib:
            cmd = f'make SIFIVESRCDIR={sfsrc} BENCHMARK={self._bm} ' + \
                  f'EXTRA_DEFS="-DSTANDARD_LIB {verify_flag}"'
        else:
            cmd = f'make LMUL={self._lmul} BENCHMARK={self._bm} ' + \
                  f'SIFIVESRCDIR={sfsrc} EXTRA_DEFS="{verify_flag}"'
        try:
            res = subprocess.run(
                cmd,
                shell=True,
                executable='/bin/bash',
                cwd=self.builddir,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=self._args.get('timeout'),
                check=True,
                )
        except subprocess.TimeoutExpired as e:
            self._log.error(
                f'ERROR: Benchmark build for {self.suffix} timed out.')
            self._log.debug(e.cmd)
            self._log.debug(e.stdout)
            self._log.debug(e.stderr)
            self.buildok = False
        except subprocess.CalledProcessError as e:
            self._log.error(
                f'ERROR: Benchmark build for {self.suffix} failed.')
            self._log.debug(e.cmd)
            self._log.debug(e.stdout)
            self._log.debug(e.stderr)
            self.buildok = False
        else:
            self._log.debug(res.stdout.decode('utf-8'))
            self.buildok = True

        return self.buildok

    def _read_icount(self, filename):
        """Extract the instruction count from a file."""
        nlines = 0
        icnt = 0
        with open(filename, 'r', encoding="utf-8") as file:
            for line in file:
                insns = re.search(r'total insns: (\d+)', line.strip())
                if insns:
                    icnt = int(insns.group(1))
                    nlines += 1

        if nlines > 1:
            mess = f'{nlines} line in icount for {self.suffix}'
            self._log.warning(f'Warning: {mess}')

        return icnt

    def _qemu_res (self, usage_start, usage_end, cntf):
        """Compute the result tuple from a usage run."""
        usr_time = usage_end.ru_utime - usage_start.ru_utime
        sys_time = usage_end.ru_stime - usage_start.ru_stime
        tot_time = usr_time + sys_time
        return (tot_time, self._read_icount(cntf))

    def _run_qemu(self, sz, iters):
        """Run a single QEMU execution of the executable benchmark.  Result on
           success is a tuple (icount, time), where "time" is the sum of user
           and system time for the child process.  Results on failure is
           None."""
        try:
            tmpf = tempfile.NamedTemporaryFile(
                mode='w', prefix='icount-', dir=self._args.get('strmemdir'),
                delete=False).name
        except Exception as e:
            estr= 'Unable to create temporary file'
            ename = type(e).__name__
            confstr = f'self._prefix, size={sz}, iters={iters}'
            self._log.error(f'ERROR: {estr} for {confstr}: {ename}.')
            return None

        # Add QEMU to path
        currpath=os.environ['PATH']
        os.environ['PATH'] = f'{self._qb.installdir}/bin:{currpath}'
        usage_start = resource.getrusage(resource.RUSAGE_CHILDREN)
        cmd = f'qemu-riscv64 -cpu rv64,v=true,vlen={self._vlen} ' + \
	      f'--d plugin -plugin {self._qemuplugin},inline=on ' + \
              f'-D {tmpf} {self._bmexe} {sz} {iters}'
        try:
            subprocess.run(
                cmd,
                shell=True,
                executable='/bin/bash',
                cwd=self.builddir,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=self._args.get('timeout'),
                check=True,
                )
        except subprocess.TimeoutExpired as e:
            wmess = f'Benchmark run for {self.suffix}'
            self._log.warning(
                f'Warning: {wmess}, size={sz}, iters={iters} timed out.')
            self._log.debug(e.cmd)
            self._log.debug(e.stdout)
            self._log.debug(e.stderr)
            return None
        except subprocess.CalledProcessError as e:
            wmess = f'Benchmark run for {self.suffix}'
            self._log.warning(
                f'Warning: {wmess}, size={sz}, iters={iters} failed.')
            self._log.debug(e.cmd)
            self._log.debug(e.stdout)
            self._log.debug(e.stderr)
            return None
        else:
            usage_end = resource.getrusage(resource.RUSAGE_CHILDREN)
            return self._qemu_res(usage_start, usage_end, tmpf)
        finally:
            try:
                os.environ['PATH'] = f'{currpath}'
                os.remove(tmpf)
            except Exception as e:
                self._log.debug('Debug: Unable to delete temporary {tmpf}')

    def _run_one(self, sz, iters):
        """Run the benchmark under QEMU for a single size.  We do a warmup run
           and then a full run, and subtract the two to remove overhead.
           Return a tuple of (iters, time, icount) on success, or None on
           failure."""
        warmup_iters = self._args.get('warmup')
        tot_iters = warmup_iters + iters
        res_warmup = self._run_qemu(sz, warmup_iters)
        if not res_warmup:
            return None

        t_warmup, icnt_warmup = res_warmup
        res_tot = self._run_qemu(sz, tot_iters)
        if not res_tot:
            return None

        t_tot, icnt_tot = res_tot

        return (iters, t_tot - t_warmup, icnt_tot - icnt_warmup)

    def run(self):
        """Run the models for all the different sizes.  Return the list of
           results on success, None on failure."""
        self._log.debug(f'DEBUG: Running {self.suffix}: {self.buildok}')
        if not self.buildok:
            self._log.debug(f'DEBUG: No build to run {self.suffix}')
            return None

        # Mark progress as successful and get the baseline icount and timing
        sizelist = self._args.get('sizelist')
        prev_sz = sizelist[0]
        if self._args.get('verify'):
            iters = Model.BASELINE_ITERS[self._bm]
        else:
            iters = Model.BASELINE_VERIF_ITERS[self._bm]
        res = self._run_one(prev_sz, iters)
        if not res:
            return None

        target_t = float(self._args.get('target_time'))
        prev_t = res[1]

        for sz in sizelist:
            iters = int(float(iters) * prev_sz / float(sz) * target_t / prev_t)
            res = self._run_one(sz, iters)
            if not res:
                return None
            self.results[sz] = res
            prev_t = res[1]
            prev_sz = float(sz)

        return self.results

    def export_csv(self):
        """Export our results to a CSV file."""
        with open(self._resfile, 'w', newline='', encoding="utf-8") as csvf:
            csvwriter = csv.writer(csvf, dialect=csv.unix_dialect)
            # Write the header
            csvwriter.writerow(['Benchmark', 'Iterations', 'VLEN', 'LMUL',
                               'Std', 'Size', 'Icount', 'Time', 'Icnt/iter',
                                'ns/inst'])
            # Write all the elements
            for sz, data in self.results.items():
                iters, tim, icnt = data
                icpi = float(icnt) / float(iters)
                nspi = float(tim) * 1000000000.0 / float(icnt)
                csvwriter.writerow([self._bm, iters, self._vlen, self._lmul,
                                    self._stdlib, sz, icnt, tim, icpi, nspi])

class ModelSet:
    """A class for all the model configurations we have to run."""
    def __init__(self, qemu_builds, args, log):
        """Constructor just creates all the models"""
        self._qemu_builds = qemu_builds
        self._args = args
        self._log = log
        self._log.info('Creating all model configurations')
        self._model_list = []
        for qb in qemu_builds:
            for bm in args.get('bmlist'):
                for conf in args.get('conflist'):
                    self._model_list.append(Model(qb, bm, conf, args, log))

    def build(self):
        """Build all the model configurations concurrently.

           An important point to remember is that we invoke these methods in
           their own process, so the model objects will be copied. Any  state
           changes will be in that copy, *not* in the original model.  Thus
           the run must return any state necessary and that explicitly placed
           in the model."""
        resf = {}
        # Launch all the builds
        self._log.info('Building all model configurations')
        with concurrent.futures.ProcessPoolExecutor() as executor:
            for m in self._model_list:
                resf[m] = executor.submit (m.build)

        # Collect the results.  We wait in the order that processes were
        # created, but that should be just fine, since they should all take
        # roughly the same time.
        #
        # Note we don't need to worry about giving a timeout, since that will
        # be handled by the subprocess calls for each model.
        successes = 0
        failures = 0
        for m, r in resf.items():
            try:
                m.buildok = r.result()
                if m.buildok:
                    successes += 1
                else:
                    failures +=1
            except Exception as e:
                emess = 'Building model'
                ename = type(e).__name__
                self._log.error(f'ERROR: {emess}: {ename}.')
                failures += 1

            print('.', end='', flush=True)

        print()
        if failures > 0:
            self._log.warning(
                f'Warning: {failures} model configs failed to build.')

        self._log.info(f'{successes} model configs built.')

    def run(self):
        """Run all the model configurations concurrently.

           An important point to remember is that we invoke these methods in
           their own process, so the model objects will be copied. Any  state
           changes will be in that copy, *not* in the original model.  Thus
           the run must return any state necessary and that explicitly placed
           in the model."""
        # Launch all the builds
        self._log.info('Running all model configurations')
        resf = {}
        with concurrent.futures.ProcessPoolExecutor() as executor:
            for m in self._model_list:
                resf[m] = executor.submit (m.run)

        # Collect the results.  We wait in the order that processes were
        # created, but that should be just fine, since they should all take
        # roughly the same time.
        #
        # Note we don't need to worry about giving a timeout, since that will
        # be handled by the subprocess calls for each model.
        successes = 0
        failures = 0
        for m, r in resf.items():
            try:
                m.results = r.result()
                if m.results:
                    successes += 1
                else:
                    failures +=1
            except Exception as e:
                emess = f'running model config {m.suffix}'
                ename = type(e).__name__
                self._log.error(f'ERROR: {emess}: {ename}.')
                failures += 1

            print('.', end='', flush=True)

        print()
        if failures > 0:
            self._log.warning(
                f'Warning: {failures} model configs failed to run.')

        self._log.info(f'{successes} model configs run.')

    def generate_csv(self):
        """Do the detailed analysis."""
        self._log.info('Exporting results as CSV')
        for m in self._model_list:
            if m.results:
                m.export_csv()
