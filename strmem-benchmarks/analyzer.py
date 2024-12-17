#!/usr/bin/env python3

# A class to do analysis of results

# Copyright (C) 2024 Embecosm Limited

# Contributor: Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

"""
We populate all the data from CSV files.  Then manipulate in useful ways.
"""

# What we export

__all__ = [
    'Analyzer',
    'GroupAnalyzer',
]

import csv
import math
import matplotlib as mpl
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import os.path
import statistics

class RunData:
    """A class to hold one row of CSV data."""
    def __init__(self, iters, icount, time, field):
        """A struct for the CSV row data. The field is the data of interest,
           which is one of
           - Icnt/iter: instruction count per iteration
           - ns/inst:   nanoseconds per instruction
           - s/Miter:   seconds per million instructions

           The struct is used in a dictionary indexed by the data size."""
        self.iters = int(iters)
        self.icount = int(icount)
        self.time = float(time)
        self.data = float(field)

class Analyzer:
    """A class to analyze benchmark results for a set of configurations.

       The configuration is defined by a tuple of the following
       - the QEMU commit being used
       - the benchmark
       - the vector length of scalar (VLEN or stdlib)

       For each configuration there is a CSV file with results for all the
       data sizes specified."""

    def __init__(self, field, args, log):
        """Constructor for the analyzer, which just reads in the data from CSV
           files.  The field is the title of the column to compute, which is
           one of:
           - 'Icnt/iter': instruction count per iteration
           - 'ns/inst':   nanoseconds per instruction
           - 's/Miter':   seconds per million instructions"""
        self._args = args
        self._log = log
        self._field = field
        self._rundata = {}
        self._data_speedup = []
        self._data_sizes = []
        # Load up all the configurations
        for qid in args.get('qemulist'):
            for bm in args.get('bmlist'):
                for vlen in args.get('vlenlist'):
                    conf = (qid, bm, vlen)
                    csvfn = os.path.join(args.get('resdir'),
                                         f'{qid}-{bm}-{vlen}.csv')

                    try:
                        with open(csvfn, newline='') as csvfile:
                            reader = csv.DictReader(csvfile,
                                                    dialect=csv.unix_dialect)
                            self._rundata[conf] = {}
                            for row in reader:
                                self._rundata[conf][int(row['Size'])] = RunData(
                                    iters = row['Iterations'],
                                    icount = row['Icount'],
                                    time = row['Time'],
                                    field = row[field])
                    except Exception as e:
                        wmess = f'Warning: Failed to read {csvfn} {field}'
                        ename = type(e).__name__
                        self._log.warning(f'{wmess}: {ename}.')

    def stats(self, bm, vlen):
        """Statistics for a pair of configurations. We are given a benchmark
           and VLEN and look at the mean and standard deviation when comparing
           the two.  We assume the first QEMU commit is the baseline."""
        qidlist = self._args.get('qemulist')
        if len(qidlist) != 2:
            self._log.info(f'Info: 2 datasets needed for {bm} and {vlen}')
            return
        conf_base = (qidlist[0], bm, vlen)
        conf_test = (qidlist[1], bm, vlen)
        rd_base_dict = self._rundata[conf_base]
        rd_test_dict = self._rundata[conf_test]
        self._data_sizes = []
        self._data_speedup = []
        for size, rundata_base in rd_base_dict.items():
            if size in rd_test_dict:
                rundata_test = rd_test_dict[size]
                self._data_sizes.append(size)
                self._data_speedup.append(
                    rundata_base.data / rundata_test.data)
            else:
                self._log.info(f'No test data for {bm}-{vlen}: {size}')

        self._data_avg = statistics.median(self._data_speedup)
        self._data_sd = statistics.stdev(self._data_speedup)
        data_avg_pc = self._data_avg * 100.0
        data_sd_pc = self._data_sd * 100.0
        data_min = min(self._data_speedup) * 100.0
        data_max = max(self._data_speedup) * 100.0
        confstr = f'{bm}-{vlen} {self._field}:'
        self._log.info(f'{confstr:<25} avg = {data_avg_pc:5.1f}%, sd = {data_sd_pc:5.1f}%, min = {data_min:5.1f}%, max = {data_max:5.1f}%')

    def plotit(self, bm, vlen):
        """Plot the speedup for this analysis."""
        # Create the average and SD lines
        size_bounds = [min(self._data_sizes), max(self._data_sizes)]
        avg=[self._data_avg, self._data_avg]
        sd_lo=[self._data_avg - self._data_sd, self._data_avg - self._data_sd]
        sd_hi=[self._data_avg + self._data_sd, self._data_avg + self._data_sd]
        fig, ax = plt.subplots(figsize=(11.69,8.27), dpi=300)
        ax.plot(self._data_sizes, self._data_speedup, lw=2, label='speedup')
        ax.plot(size_bounds, avg, lw=2, color='k', label='mean')
        ax.plot(size_bounds, sd_lo, lw=1, ls='--', color='0.8', label='sd')
        ax.plot(size_bounds, sd_hi, lw=1, ls='--', color='0.8')
        ax.set_xscale('log', base=16.0, subs=[2,4,8])
        ax.xaxis.set_major_formatter(ticker.StrMethodFormatter('{x:,.0f}'))
        ax.set_xlabel('Data size/bytes')
        ax.set_ylabel('Speedup')
        handles, labels = ax.get_legend_handles_labels()
        ax.legend(handles, labels, loc='upper left')
        if vlen == 'stdlib':
            plt.title(f'{bm} standard library')
        else:
            plt.title(f'{bm} VLEN={vlen}')
        plt.savefig(f'{bm}-{vlen}-speedup.pdf', orientation = 'portrait',
                    format = 'pdf')
        plt.close(fig)

class GroupAnalyzer:
    """A class to analyze multiple benchmark results for a particular pair of
       configurations from multiple runs. The primary purpose is statistical
       analysis of multiple runs.

       The configuration is defined by a tuple of the following
       - the QEMU commit being used
       - the benchmark
       - the vector length of scalar (VLEN or stdlib)

       For each configuration there is a CSV file with results for all the
       data sizes specified."""

    def _validate_args(self, args):
        """We use the generic argument parsing, but we are constrained to
           working with just two QEMU commits, one benchmark, one VLEN and at
           least three result directories (fewer and we can't do any
           stats).  Failure on any of these is critical and we exit."""
        if len(args.get('qemulist')) != 2:
            emess = 'Must specify exactly two QEMU commits'
            self._log.critical(f'ERROR: {emess}: Exiting')
            sys.exit(1)
        if len(args.get('bmlist')) != 1:
            emess = 'Must specify exactly one benchmark'
            self._log.critical(f'ERROR: {emess}: Exiting')
            sys.exit(1)
        if len(args.get('vlenlist')) != 1:
            emess = 'Must specify exactly one VLEN'
            self._log.critical(f'ERROR: {emess}: Exiting')
            sys.exit(1)
        if len(args.get('resdirlist')) < 3:
            emess = 'Must specify at least 3 results directories'
            self._log.critical(f'ERROR: {emess}: Exiting')
            sys.exit(1)

    def __init__(self, field, args, log):
        """Constructor for the analyzer, which just reads in the data from CSV
           files.  The field is the title of the column to compute, which is
           one of:
           - 'Icnt/iter': instruction count per iteration
           - 'ns/inst':   nanoseconds per instruction
           - 's/Miter':   seconds per million instructions

           We check that exactly two QEMU commits are specified"""
        # Capture the arguments
        self._args = args
        self._log = log
        self._field = field
        # Checke we have valid arguments
        self._validate_args(args)
        # Extract the various arguments we need
        qemulist = [args.get('qemulist')[0], args.get('qemulist')[1]]
        bm = args.get('bmlist')[0]
        vlen = args.get('vlenlist')[0]
        resdirlist = args.get('resdirlist')
        # Construct the data
        self._allres = {}
        for rd in resdirlist:
            # Get the individual results
            res = [{}, {}]
            for i in [0, 1]:
               csvfn = os.path.join(rd, f'{qemulist[i]}-{bm}-{vlen}.csv')
               try:
                  with open(csvfn, newline='') as csvfile:
                     reader = csv.DictReader(csvfile,
                                             dialect=csv.unix_dialect)
                     for row in reader:
                        res[i][int(row['Size'])] = float(row[field])
               except Exception as e:
                  wmess = f'Failed to read {csvfn} {field}'
                  ename = type(e).__name__
                  self._log.warning(f'Warning: {wmess}: {ename}.')
            # Combine the results
            for k, v in res[0].items():
               if k in res[1]:
                  speedup = res[0][k] / res[1][k]
                  if k in self._allres:
                     self._allres[k].append(speedup)
                  else:
                     self._allres[k] = [speedup]
               else:
                  wmess = f'data for {k} missing from test dataset'
                  self._log.warning(f'Warning: {wmess}')

    def stats(self):
        """Generate the statistics for the grouped results. For each row, we
           compute the average and the standard error."""
        self._mean = {}
        self._stderr = {}
        for k, v in self._allres.items():
            self._mean[k] = statistics.mean(self._allres[k])
            self._stderr[k] = (statistics.stdev(self._allres[k]) /
                              math.sqrt(len(self._allres[k])))
        # Summary
        npts = len(self._args.get('resdirlist'))
        bm = self._args.get('bmlist')[0]
        vlen = self._args.get('vlenlist')[0]
        mean = statistics.mean(self._mean.values())
        stderr = statistics.mean(self._stderr.values())
        if vlen == 'stdlib':
            intro = f'{bm} stdlib:'
        else:
            intro = f'{bm} VLEN={vlen}:'
        self._log.info(f'{intro:18s} mean = {mean:5.2f}, stderr = {stderr:5.2f}, runs = {npts:2d}')

    def plotit(self):
        """Plot the speedup for this analysis."""
        # Create the average and SD lines
        size_bounds = [min(self._mean.keys()), max(self._mean.keys())]
        fig, ax = plt.subplots(figsize=(11.69,8.27), dpi=300)
        ax.errorbar(self._mean.keys(), self._mean.values(),
                    yerr=list(self._stderr.values()), lw=2, label='speedup',
                    elinewidth=1, capsize=3.0, ecolor='black')
        ax.set_xscale('log', base=16.0, subs=[2,4,8])
        ax.xaxis.set_major_formatter(ticker.StrMethodFormatter('{x:,.0f}'))
        ax.set_xlabel('Data size/bytes')
        ax.set_ylabel('Speedup')
        ax.grid(which='major', axis='y')
        ax.set_ylim(0, 1.5)
        handles, labels = ax.get_legend_handles_labels()
        ax.legend(handles, labels, loc='upper right')
        qid = self._args.get('qemulist')[1]
        bm = self._args.get('bmlist')[0]
        vlen = self._args.get('vlenlist')[0]
        if vlen == 'stdlib':
            plt.title(f'{bm} standard library')
        else:
            plt.title(f'{bm} VLEN={vlen}')
        plt.savefig(f'{bm}-{qid}-{vlen}-speedup.pdf',
                    orientation = 'portrait', format = 'pdf')
        plt.close(fig)
