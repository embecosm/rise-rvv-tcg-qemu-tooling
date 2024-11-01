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
    """A class to build a QEMU instance from a particular commit.

       The install and build paths are derived from the generic install and
       build paths passed as arguments.
    """
    def __init__(self, cmt, args, log):
        """Constructor for the builder, which actually does the building."""
        suffix = 'qemu-' + str(cmt)
        self.cmt = cmt
        self._args = args
        self._log = log
        self.builddir = os.path.join(args.get('builddir'), suffix)
        self.installdir = os.path.join(args.get('installdir'), suffix)
        self._log.info(f'Building QEMU commit {self.cmt}')
        self._build_qemu()
        self.qemuplugin = self._find_qemu_plugin()
        if not self.qemuplugin:
            log.error(f'ERROR: Unable to find QEMU plugin for {self._suffix}')
            sys.exit(1)

    def _checkout(self):
        """Checkout the desired QEMU commit. Give up on failure."""
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
                timeout=60,
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

    def _clean(self):
        """Prepare a clean build.  Since they are used for nothing else, we
           can just delete the build and install directories if they exist.
           Give up on failure."""
        self._log.debug(f'DEBUG: Cleaning QEMU commit {self.cmt}')
        try:
            shutil.rmtree(self.builddir, ignore_errors=True)
        except Exception as e:
            ename=type(e)._name_
            self._log.error(
                f'ERROR: Clean of QEMU build dir {self.builddir} failed: {ename}.')
            sys.exit(1)
        try:
            shutil.rmtree(self.installdir, ignore_errors=True)
        except Exception as e:
            self._log.error(
                f'ERROR: Clean of QEMU install dir {self.installdir} failed: {ename}.')
            sys.exit(1)

    def _configure(self):
        """Configure the desired QEMU commit. Give up on failure."""
        self._log.debug(f'DEBUG: Configuring QEMU commit {self.cmt}')
        # Create the build directory.
        try:
            os.makedirs(self.builddir, exist_ok=True)
        except FileNotFoundError:
            self._log.error(
                f'ERROR: Unable to create QEMU build dir {self.builddir}.')
            sys.exit(1)

        # Configure in the build directory
        configure=os.path.join(self._args.get('qemudir'), 'configure')
        sysroot_prefix=os.path.join(self._args.get('installdir'), 'sysroot')
        extra_cflags=self._args.get('qemu_cflags')
        cmd = f'{configure} --prefix={self.installdir} ' \
              f'--target-list=riscv64-linux-user,riscv32-linux-user ' \
              f'--interp-prefix={sysroot_prefix} --disable-docs ' \
              f'--extra-cflags="{extra_cflags}"' + \
              ' '.join(self._args.get('qemu_config'))
        try:
            res = subprocess.run(
                cmd,
                shell=True,
                executable='/bin/bash',
                cwd=self.builddir,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=60,
                check=True,
                )
            self._log.debug(res.stdout.decode('utf-8'))
        except subprocess.TimeoutExpired as e:
            self._log.error(
                f'ERROR: Configure of QEMU commit {self.cmt} timed out.')
            self._log.debug(e.stdout)
            self._log.debug(e.stderr)
            sys.exit(1)
        except subprocess.CalledProcessError as e:
            self._log.error(
                f'ERROR: Configure of QEMU commit {self.cmt} failed.')
            self._log.debug(f'Return code {e.returncode}')
            self._log.debug(' '.join(e.cmd))
            self._log.debug(e.stdout)
            self._log.debug(e.stderr)
            sys.exit(1)

    def _build(self):
        """Build the configured QEMU, giving up on failure"""
        self._log.debug(f'DEBUG: Building QEMU commit {self.cmt}')
        nprocs=str(multiprocessing.cpu_count())
        cmd = f'make -j {nprocs}'
        try:
            res = subprocess.run(
                cmd,
                shell=True,
                executable='/bin/bash',
                cwd=self.builddir,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=600,
                check=True,
                )
            self._log.debug(res.stdout.decode('utf-8'))
        except subprocess.TimeoutExpired as e:
            self._log.error(
                f'ERROR: Build of QEMU commit {self.cmt} timed out.')
            self._log.debug(e.stderr)
            sys.exit(1)
        except subprocess.CalledProcessError as e:
            self._log.error(
                f'ERROR: Build of QEMU commit {self.cmt} failed.')
            self._log.debug(e.stderr)
            sys.exit(1)

    def _install(self):
        """Install the configured QEMU, giving up on failure"""
        self._log.debug(f'DEBUG: Installing QEMU commit {self.cmt}')
        cmd = 'make install'
        try:
            res = subprocess.run(
                cmd,
                shell=True,
                executable='/bin/bash',
                cwd=self.builddir,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=60,
                check=True,
                )
            self._log.debug(res.stdout.decode('utf-8'))
        except subprocess.TimeoutExpired as e:
            self._log.error(
                f'ERROR: Install of QEMU commit {self.cmt} timed out.')
            self._log.debug(e.stderr)
            sys.exit(1)
        except subprocess.CalledProcessError as e:
            self._log.error(
                f'ERROR: Install of QEMU commit {self.cmt} failed.')
            self._log.debug(e.stderr)
            sys.exit(1)

    def _validate(self):
        """Check the binaries exist in the install directory."""
        q32=os.path.join(self.installdir, 'bin', 'qemu-riscv32')
        q64=os.path.join(self.installdir, 'bin', 'qemu-riscv64')
        for f in [q32, q64]:
            if not os.path.exists(f):
                self._log.error(f'ERROR: {f} not installed.')
                sys.exit(1)

    def _build_qemu(self):
        """Build and install an instance of QEMU.  This is always a clean
           build.  Any failures terminate the program.

           If no-build is requested, we check the binaries are there."""
        if (self._args.get('build')):
            self._checkout()
            self._clean()
            self._configure()
            self._build()
            self._install()
        else:
            self._validate()

    def _find_qemu_plugin(self):
        """Find the QEMU libinsn plugin from its build directory.  This moves
           around depending on the specific QEMU version (sigh).  Return the
           fully qualified plugin name, or None on failure."""
        bd = self.builddir
        plugin_dirs = [
            os.path.join(bd, 'tests', 'plugin', 'libinsn.so'),
            os.path.join(bd, 'tests', 'tcg', 'plugins', 'libinsn.so'), ]
        for plugin in plugin_dirs:
            if os.path.exists(plugin):
                return plugin

        self._log.error('ERROR: QEMU plugin not found.')
        return None

