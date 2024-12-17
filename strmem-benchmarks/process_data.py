#!/usr/bin/env python3

# Script to run all the SiFive benchmarks

# Copyright (C) 2017, 2019, 2024 Embecosm Limited
#
# Contributor: Graham Markall <graham.markall@embecosm.com>
# Contributor: Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

"""This is the main entry point for benchmarking all the SiFive functions.

It is based on a generic Embecosm framework for such benchmarking.
"""

import sys

from support import Log
from support import check_python_version
from parseargs import ParseArgs
from analyzer import Analyzer

def main():
    """Main program driving calculations"""
    log = Log()
    args = ParseArgs()
    log.setup(args.get('logdir'),
              args.get('log_prefix') + '-' + args.get('datestamp') + '.log')
    args.logall(log)
    # Analyze the results. Creation will populate the class from CSV files.
    # for stat in ['Icnt/iter', 'ns/inst', 's/Miter']:
    for stat in ['s/Miter']:
        ana = Analyzer(stat, args, log)
        for vlen in ['stdlib', '128', '1024']:
            for bm in args.get('bmlist'):
                ana.stats(bm, vlen)
                ana.plotit(bm, vlen)

# Make sure we have new enough Python and only run if this is the main package
check_python_version(3, 10)
if __name__ == '__main__':
    sys.exit(main())
