#!/usr/bin/env python3

# QEMU building for modeling

# Copyright (C) 2024 Embecosm Limited

# Contributor: Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

"""
A module to build QEMU from a particular commit.

Note that we don't have to do this in parallel, since each build should fully
load up the machine anyway.
"""

import multiprocessing
import os
import os.path
import shutil
import subprocess
import sys

# What we export

__all__ = [
    'QEMUBuilder',
]

class QEMUBuilder:
    """A class to build a pair of QEMU instances from a particular commit.

       We build one with plugins enabled and one without.

       The install and build paths are derived from the generic install and
       build paths passed as arguments.
    """
    def __init__(self, cmt, args, log):
        """Constructor for the builder, which actually does the building."""
        base_suffix = 'qemu-' + str(cmt) + '-'
        base_bd = args.get('builddir')
        base_id = args.get('installdir')
        self.cmt = cmt
        self._args = args
        self._log = log
        self.builddir = {}
        self.installdir = {}
        # Build plugin and no plugin versions.  Only checkout once
        do_checkout = True
        for plt in ['plugin', 'no-plugin']:
            self.builddir[plt] = os.path.join(base_bd, base_suffix + plt)
            self.installdir[plt] = os.path.join(base_id, base_suffix + plt)
            self._log.info(f'Building QEMU commit {self.cmt} {plt} version')
            self._build_qemu(plt, do_checkout)

        # Only have a QEMU plugin in one case
        self.qemuplugin = self._find_qemu_plugin()
        if not self.qemuplugin:
            emess = 'ERROR: Unable to find QEMU plugin'
            log.error(f'{emess} for commit {self.cmt} {plt} version')
            sys.exit(1)

    def _checkout(self):
        """Checkout the desired QEMU commit. Give up on failure.
        """
        self._log.debug(f'DEBUG: Checking out QEMU commit {self.cmt}')
        cmd = f'git checkout {self.cmt}'
        try:
            res = subprocess.run(
                cmd,
                shell=True,
                executable='/bin/bash',
                cwd=self._args.get('qemudir'),
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=self._args.get('timeout'),
                check=True,
                )
        except subprocess.TimeoutExpired as e:
            self._log.error(
                f'ERROR: Checkout of QEMU commit {self.cmt} timed out.')
            self._log.debug(' '.join(e.cmd))
            self._log.debug(e.stdout)
            self._log.debug(e.stderr)
            sys.exit(1)
        except subprocess.CalledProcessError as e:
            self._log.error(
                f'ERROR: Checkout of QEMU commit {self.cmt} failed.')
            self._log.debug(' '.join(e.cmd))
            self._log.debug(e.stdout)
            self._log.debug(e.stderr)
            sys.exit(1)
        else:
            if not res:
                self._log.error(
                    f'ERROR: Checkout of QEMU commit {self.cmt} failed.')
                sys.exit(1)

    def _clean(self, plt):
        """Prepare a clean build.  Argument supplied is 'plugin' or
           'no-plugin'.  Since they are used for nothing else, we can just
           delete the build and install directories if they exist.
           Give up on failure."""
        self._log.debug(f'DEBUG: Cleaning QEMU commit {self.cmt}')
        try:
            shutil.rmtree(self.builddir[plt], ignore_errors=True)
        except Exception as e:
            ename=type(e).__name__
            self._log.error(
                emess = 'ERROR: Clean of QEMU build dir'
                f'{emess} {self.builddir[plt]} failed: {ename}.')
            sys.exit(1)
        try:
            shutil.rmtree(self.installdir[plt], ignore_errors=True)
        except Exception as e:
            ename=type(e).__name__
            emess = 'ERROR: Clean of QEMU install dir'
            self._log.error(
                f'{emess} {self.installdir[plt]} failed: {ename}.')
            sys.exit(1)

    def _configure(self, plt):
        """Configure the desired QEMU commit.  Argument supplied is 'plugin'
           or 'no-plugin', which controls how we configure the build.  Give up
           on failure."""
        dmess = 'DEBUG: Configuring QEMU'
        self._log.debug(f'{dmess} commit {self.cmt} {plt} version')
        # Create the build directory.
        try:
            os.makedirs(self.builddir[plt], exist_ok=True)
        except FileNotFoundError:
            self._log.error(
                emess = 'ERROR: Unable to create QEMU build dir'
                f'{emess} {self.builddir[plt]}.')
            sys.exit(1)

        # Configure in the build directory
        configure=os.path.join(self._args.get('qemudir'), 'configure')
        sysroot_prefix=os.path.join(self._args.get('installdir'), 'sysroot')
        extra_cflags=self._args.get('qemu_cflags')
        if plt == 'plugin':
            pluginconf = '--enable-plugins'
        else:
            pluginconf = '--disable-plugins'
        cmd = f'{configure} --prefix={self.installdir[plt]} ' \
              f'--target-list=riscv64-linux-user,riscv32-linux-user ' \
              f'--interp-prefix={sysroot_prefix} --disable-docs ' \
              f'{pluginconf} --extra-cflags="{extra_cflags}"' + \
              ' '.join(self._args.get('qemu_config'))
        try:
            res = subprocess.run(
                cmd,
                shell=True,
                executable='/bin/bash',
                cwd=self.builddir[plt],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=self._args.get('timeout'),
                check=True,
                )
            self._log.debug(res.stdout.decode('utf-8'))
        except subprocess.TimeoutExpired as e:
            emess = 'ERROR: Configure of QEMU commit'
            self._log.error(
                f'{emess} {self.cmt} {plt} version timed out.')
            self._log.debug(e.stdout)
            self._log.debug(e.stderr)
            sys.exit(1)
        except subprocess.CalledProcessError as e:
            emess = 'ERROR: Configure of QEMU commit'
            self._log.error(
                f'{emess} {self.cmt} {plt} version failed.')
            self._log.debug(f'Return code {e.returncode}')
            self._log.debug(' '.join(e.cmd))
            self._log.debug(e.stdout)
            self._log.debug(e.stderr)
            sys.exit(1)

    def _build(self, plt):
        """Build the configured QEMU, giving up on failure.  Argument supplied
           is 'plugin' or 'no-plugin'."""
        dmess = 'DEBUG: Building QEMU'
        self._log.debug(f'{dmess} commit {self.cmt} {plt} version')
        nprocs=str(multiprocessing.cpu_count())
        cmd = f'make -j {nprocs}'
        try:
            res = subprocess.run(
                cmd,
                shell=True,
                executable='/bin/bash',
                cwd=self.builddir[plt],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=10 * self._args.get('timeout'),
                check=True,
                )
            self._log.debug(res.stdout.decode('utf-8'))
        except subprocess.TimeoutExpired as e:
            emess = 'ERROR: Build of QEMU'
            self._log.error(
                f'{emess} commit {self.cmt} {plt} version timed out.')
            self._log.debug(e.stderr)
            sys.exit(1)
        except subprocess.CalledProcessError as e:
            emess = 'ERROR: Build of QEMU'
            self._log.error(
                f'{emess} commit {self.cmt} {plt} version failed.')
            self._log.debug(e.stderr)
            sys.exit(1)

    def _install(self, plt):
        """Install the configured QEMU, giving up on failure.  Argument supplied
           is 'plugin' or 'no-plugin'."""
        dmess = 'DEBUG: Installing QEMU'
        self._log.debug(f'{dmess} commit {self.cmt} {plt} version.')
        cmd = 'make install'
        try:
            res = subprocess.run(
                cmd,
                shell=True,
                executable='/bin/bash',
                cwd=self.builddir[plt],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=self._args.get('timeout'),
                check=True,
                )
            self._log.debug(res.stdout.decode('utf-8'))
        except subprocess.TimeoutExpired as e:
            emess = 'ERROR: Install of QEMU'
            self._log.error(
                f'{emess} commit {self.cmt} {plt} version timed out.')
            self._log.debug(e.stderr)
            sys.exit(1)
        except subprocess.CalledProcessError as e:
            emess = 'ERROR: Install of QEMU'
            self._log.error(
                f'{emess} commit {self.cmt} {plt} version failed.')
            self._log.debug(e.stderr)
            sys.exit(1)

    def _validate(self, plt):
        """Check the binaries exist in the install directory.  Argument
           supplied is 'plugin' or 'no-plugin'."""
        q32=os.path.join(self.installdir[plt], 'bin', 'qemu-riscv32')
        q64=os.path.join(self.installdir[plt], 'bin', 'qemu-riscv64')
        for f in [q32, q64]:
            if not os.path.exists(f):
                emess = f'ERROR: {f} not installed'
                self._log.error(f'{emess} for commit {self.cmt} version {plt}.')
                sys.exit(1)

    def _build_qemu(self, plt, do_checkout):
        """Build and install an instance of QEMU.  First argument supplied
           is 'plugin' or 'no-plugin', second is wether we need to checkout
           the commit.  This is always a clean build.  Any failures terminate
           the program.

           If no-build is requested, we check the binaries are there."""
        if self._args.get('build'):
            if do_checkout:
                self._checkout()
            self._clean(plt)
            self._configure(plt)
            self._build(plt)
            self._install(plt)
        else:
            self._validate(plt)

    def _find_qemu_plugin(self):
        """Find the QEMU libinsn plugin from its build directory.  This
           directory  moves around depending on the specific QEMU version
           (sigh).  Return the fully qualified plugin name, or None on
           failure."""
        bd = self.builddir['plugin']
        plugin_dirs = [
            os.path.join(bd, 'tests', 'plugin', 'libinsn.so'),
            os.path.join(bd, 'tests', 'tcg', 'plugins', 'libinsn.so'), ]
        for plugin in plugin_dirs:
            if os.path.exists(plugin):
                return plugin

        return None
