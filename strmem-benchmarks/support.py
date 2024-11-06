#!/usr/bin/env python3

# Common python procedures for benchmarking

# Copyright (C) 2017, 2019, 2024 Embecosm Limited

# Contributor: Graham Markall <graham.markall@embecosm.com>
# Contributor: Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

"""
Benchmarking common procedures.
"""

import logging
import os
import sys


# What we export

__all__ = [
    'Log',
    'check_python_version',
]


class Log:
    """A class to handle all our logging needs."""
    def __init__(self):
        self.__log = logging.getLogger()

    def __create_logdir(self, logdir):
        """Create the log directory, which we make absolute"""
        if not os.path.isabs(logdir):
            logdir = os.path.abspath(logdir)

            if not os.path.isdir(logdir):
                try:
                    os.makedirs(logdir)
                except PermissionError:
                    print(f'ERROR: Unable to create log directory {logdir}',
                          file=sys.stderr)
                    sys.exit(1)

            if not os.access(logdir, os.W_OK):
                print(f'ERROR: Unable to write to log directory {logdir}',
                    file=sys.stderr)

        return logdir


    def setup(self, logdir, logfile):
        """Set up logging in the directory specified by "logdir".

           Debug messages only go to file, everything else also goes to the
           console."""

        # Create the log directory first if necessary.
        logdir_abs = self.__create_logdir(logdir)
        logfile = os.path.join(logdir_abs, logfile)

        # Set up logging
        self.__log.setLevel(logging.DEBUG)
        cons_h = logging.StreamHandler(sys.stdout)
        cons_h.setLevel(logging.INFO)
        self.__log.addHandler(cons_h)
        file_h = logging.FileHandler(logfile)
        file_h.setLevel(logging.DEBUG)
        self.__log.addHandler(file_h)

        # Log where the log file is
        self.__log.debug('Log file: %s', logfile)
        self.__log.debug('')

    def critical(self, *args):
        """Wrapper for the underlying log critical method."""
        self.__log.critical(*args)

    def error(self, *args):
        """Wrapper for the underlying log error method."""
        self.__log.error(*args)

    def warning(self, *args):
        """Wrapper for the underlying log warning method."""
        self.__log.warning(*args)

    def info(self, *args):
        """Wrapper for the underlying log info method."""
        self.__log.info(*args)

    def debug(self, *args):
        """Wrapper for the underlying log debug method."""
        self.__log.debug(*args)


# Make sure we have new enough python.  This is will predate logging being set
# up, so just print any error message.
def check_python_version(major, minor):
    """Check the python version is at least {major}.{minor}."""
    if ((sys.version_info[0] < major)
        or ((sys.version_info[0] == major) and (sys.version_info[1] < minor))):
        print(f'ERROR: Requires Python {major}.{minor} or later',
              file=sys.stderr)
        sys.exit(1)
