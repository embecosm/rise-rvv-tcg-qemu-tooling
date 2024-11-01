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

import concurrent.futures
import os
import sys

from support import Log
from support import check_python_version
from parseargs import ParseArgs
from qemutools import QEMUBuilder
from modeling import Model
from modeling import ModelSet
from reporting import Reporter

def main():
    """Main program driving calculations"""
    log = Log()
    args = ParseArgs()
    log.setup(args.get('logdir'),
              args.get('log_prefix') + '-' + args.get('datestamp') + '.log')
    args.logall(log)
    # Create the QEMU executables
    qemu_builds = []
    for cmt in args.get('qemulist'):
        qemu_builds.append(QEMUBuilder(cmt, args, log))
    # Unless we are just reporting, create all the configurations, then build
    # them in parallel, then run them in parallel, then post-process.
    if not args.get('report_only'):
        res = ModelSet(qemu_builds, args, log)
        res.build()
        res.run()
        res.generate_csv()
    # Report the results
    rpt = Reporter(ModelSet, args, log)
    rpt.genReport()

# Make sure we have new enough Python and only run if this is the main package
check_python_version(3, 10)
if __name__ == '__main__':
    sys.exit(main())
