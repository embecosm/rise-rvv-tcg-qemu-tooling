#!/usr/bin/env python3

# Argument parsing for the SiFive benchmarks

# Copyright (C) 2024 Embecosm Limited

# Contributor: Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

"""
A module to parse arguments for the SiFive benchmarks
"""

import argparse
import os
import os.path
import sys
import time


# What we export

__all__ = [
    'ParseArgs',
]


class ParseArgs:
    """A class to parse args for the SiFive benchmarks.

       Almost all the work is done in the instance creation.  Note that at
       this time we don't have logging set up, so any error messages are just
       written to stderr.
    """
    def __init__(self):
        parser = self._build_parser()
        self.args = parser.parse_args()
        self._fix_args()
        self._argsdict = vars(self.args)

    def _build_parser(self):
        """The parser for the SiFive benchmarks"""
        parser = argparse.ArgumentParser(
            description='Run a range of SiFive benchmarks')

        # When we run
        datestamp = time.strftime('%Y-%m-%d-%H-%M-%S')
        # Some default lists (and choices) for convenience
        bmlist_dft = ['memchr', 'memcmp', 'memcpy', 'memmove', 'memset',
                      'strcat', 'strchr', 'strcmp', 'strcpy', 'strlen',
                      'strncat', 'strncmp', 'strncpy', 'strnlen',]
        sizelist_dft = [    1,     2,     3,     4,     5,     7,
                            8,     9,    11,    16,    25,    27,
                           32,    49,    64,    81,   121,   125,
                          128,   243,   256,   343,   512,   625,
                          729,  1024,  1331,  2048,  2401,  3125,
                         4096,  6561,  8192, 14641, 15625, 16384,
                        16807, 19683, 32768, 59049, 65536, 78125,]
        conflist_dft = ['stdlib', '128-1', '1024-8']
        conflist_choices = ['stdlib',
                             '128-1',  '128-2',  '128-4',  '128-8',
                             '256-1',  '256-2',  '256-4',  '256-8',
                             '512-1',  '512-2',  '512-4',  '512-8',
                            '1024-1', '1024-2', '1024-4', '1024-8',]
        # Useful default directories
        strmemdir_dft = os.path.dirname(os.path.abspath(sys.argv[0]))
        tooldir_dft = os.path.dirname(strmemdir_dft)
        topdir_dft = os.path.dirname(tooldir_dft)
        builddir_dft = os.path.join (topdir_dft, 'build')
        installdir_dft = os.path.join (topdir_dft, 'install')
        qemudir_dft = os.path.join (topdir_dft, 'qemu')
        sifivesrcdir_dft = os.path.join (topdir_dft, 'sifive-libc', 'src')

        # The arguments
        parser.add_argument(
            '--datestamp',
            type=str,
            default=datestamp,
            help=argparse.SUPPRESS,
        )
        parser.add_argument(
            '--topdir',
            type=str,
            default=topdir_dft,
            metavar='DIR',
            help='Top level directory for the benchmarking (default: %(default)s)',
        )
        parser.add_argument(
            '--tooldir',
            type=str,
            default=tooldir_dft,
            metavar='DIR',
            help='Tooling directory for the benchmarking (default: %(default)s)',
        )
        parser.add_argument(
            '--strmemdir',
            type=str,
            default=strmemdir_dft,
            metavar='DIR',
            help='String/memory tooling directory for the benchmarking (default: %(default)s)',
        )
        parser.add_argument(
            '--qemudir',
            type=str,
            default=qemudir_dft,
            metavar='DIR',
            help='Qemu source directory for the benchmarking (default: %(default)s)',
        )
        parser.add_argument(
            '--installdir',
            type=str,
            default=installdir_dft,
            metavar='DIR',
            help='Main directory for installing programs ' \
                 'for the benchmarking (default: %(default)s)',
        )
        parser.add_argument(
            '--sifivesrcdir',
            type=str,
            default=sifivesrcdir_dft,
            metavar='DIR',
            help='Source directory for the SiFive benchmarks (default: %(default)s)',
        )
        parser.add_argument(
            '--builddir',
            type=str,
            default=builddir_dft,
            metavar='DIR',
            help='Build directory for the benchmarking (default: %(default)s)',
        )
        parser.add_argument(
            '--bmlist',
            type=str,
            default=bmlist_dft,
            nargs='*',
            choices=bmlist_dft,
            metavar='BENCHMARK',
            help='Benchmarks to run (default: %(default)s)',
        )
        parser.add_argument(
            '--verify',
            action='store_true',
            default=False,
            help='Just verify correct behavior of the benchmark (default: %(default)s)',
        )
        parser.add_argument(
            '--no-verify',
            action='store_false',
             dest="verify",
            help='Do not verify correct behavior of the benchmark',
        )
        parser.add_argument(
            '--qemulist',
            type=str,
            nargs='+',
            default=[],
            required=True,
            metavar='COMMIT',
            help='QEMU commits to be benchmarked (at least one required)',
        )
        parser.add_argument(
            '--qemu-config',
            type=str,
            nargs='*',
            default=[],
            metavar='FLAG',
            help='Additional QEMU configuration flags',
        )
        parser.add_argument(
            '--qemu-cflags',
            type=str,
            default="",
            metavar='FLAGS',
            help='String of additional QEMU C compilation flags',
        )
        parser.add_argument(
            '--build',
            action='store_true',
            default=True,
            help='Build QEMU (default: %(default)s)'
        )
        parser.add_argument(
            '--no-build',
            action='store_false',
            dest="build",
            help='Do not build QEMU',
        )
        parser.add_argument(
            '--target-time',
            type=int,
            default=10,
            metavar='SECS',
            help='Target time in seconds for each benchmark execution (default: %(default)s)',
        )
        parser.add_argument(
            '--warmup',
            type=int,
            default=1,
            metavar='NUM',
            help='Iterations for warmup (default: %(default)s)',
        )
        parser.add_argument(
            '--sizelist',
            type=int,
            default=sizelist_dft,
            nargs='*',
            metavar='NUM',
            help='Sizes of data to use (default: %(default)s)',
        )
        parser.add_argument(
            '--conflist',
            type=str,
            default=conflist_dft,
            nargs='*',
            choices=conflist_choices,
            metavar='VLEN-LMUL',
            help='VLEN-LMUL configurations to run (default: %(default)s)',
        )
        parser.add_argument(
            '--log-prefix',
            type=str,
            default='rab',
            metavar='STR',
            help='Logfile name prefix',
        )
        parser.add_argument(
            '--logdir',
            type=str,
            default=os.path.join(os.getcwd(), 'logs'),
            metavar='DIR',
            help='Log directory (default %(default)s)',
        )
        parser.add_argument(
            '--report',
            action='store_true',
            default=True,
            help='Report results graphically (default: %(default)s)'
        )
        parser.add_argument(
            '--no-report',
            action='store_false',
            dest="report",
            help='Do not report results graphically',
        )
        parser.add_argument(
            '--resdir',
            type=str,
            default=None,
            metavar='DIR',
            help='Results directory (default results-<DATESTAMP>)',
        )
        parser.add_argument(
            '--report-only',
            action='store_true',
            default=False,
            help='Only prepare a report from existing results (default: %(default)s)'
        )
        parser.add_argument(
            '--timeout',
            type=int,
            default=120,
            metavar='SECS',
            help='Timeout in seconds for each benchmark execution (default: %(default)s)',
        )

        return parser

    def _fix_args(self):
        """Fix up arguments that can only be finalized after parsing."""
        if not self.args.resdir:
            self.args.resdir = os.path.join (self.args.strmemdir,
                                             'results-' + self.args.datestamp)
        else:
            self.args.resdir = os.path.abspath(self.args.resdir)

    def get(self, name):
        """Alternative access by naming the arg."""
        return self._argsdict[name]

    def logall(self, log):
        """Dump all the args to the logfile"""
        log.debug ('Argument values:')
        for k, v in self._argsdict.items():
            log.debug (f'  {k:<12s} : {v}')
        log.debug ('')
