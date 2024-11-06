#!/usr/bin/env python3

# The class to report results

# Copyright (C) 2024 Embecosm Limited

# Contributor: Jeremy Bennett <jeremy.bennett@embecosm.com>

# SPDX-License-Identifier: GPL-3.0-or-later

"""
We have a set of CSV files from which we report.
"""

import os
import os.path
import shutil
import subprocess
import tempfile
import textwrap

# What we export

__all__ = [
    'Reporter',
]

class Reporter:
    """A class to report results.

       We cannot assume that the modeling structures will be present, since we
       can chose just to report existing results.  So we have to create all
       data structures from what we have."""

    def __init__(self, modelset, args, log):
        """Constructor for the reporter, which resurrects the data"""
        self._modelset = modelset
        self._args = args
        self._log = log
        self.results = {}
        self._setup()

    def _setup(self):
        """Figure out all the results we have."""
        resdir = self._args.get('resdir')
        for cmt in self._args.get('qemulist'):
            self.results[cmt] = {}
            for bm in self._args.get('bmlist'):
                self.results[cmt][bm] = {}
                for conf in self._args.get('conflist'):
                    if conf == 'stdlib':
                        resname = f'{cmt}-{bm}-{conf}.csv'
                    else:
                        vlen, lmul = conf.split('-')
                        resname = f'{cmt}-{bm}-{vlen}-m{lmul}.csv'

                    resfile = os.path.join(resdir, resname)
                    if os.path.exists(resfile):
                        self.results[cmt][bm][conf] = resfile
                    else:
                        self.results[cmt][bm][conf] = None
                        self._log.debug(f'DEBUG: Did not find {resfile}')

    def _report_version(self, cmd, fh, width):
        """The cmd should report a tool's version. Write this to the given
           file handle, folding at the given width."""
        try:
            res = subprocess.run(
                cmd,
                shell=True,
                executable='/bin/bash',
                cwd=self._args.get('strmemdir'),
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                timeout=self._args.get('timeout'),
                check=True,
            )
        except subprocess.TimeoutExpired as e:
            self._log.error(
                'ERROR: Version extraction timed out.')
            self._log.debug(e.cmd)
            self._log.debug(e.stdout)
            fh.write('Not available: timed out.\n')
        except subprocess.CalledProcessError as e:
            self._log.error(
                'ERROR: Version extraction failed.')
            self._log.debug(e.cmd)
            self._log.debug(e.stdout)
            fh.write('Not available: failed.\n')
        else:
            fh.write('```\n')
            lines = textwrap.fill(res.stdout.decode('utf-8'), width=width,
                                  break_on_hyphens=False)
            fh.write(f'{lines}\n')
            fh.write('```\n')

    def _report_main(self, omitlist):
        """Generate the main section of the report.  Return the PDF file
           generated or None on failure."""
        tmpmd = tempfile.NamedTemporaryFile(
            mode='w', prefix='report-', suffix='.md',
            dir=self._args.get('strmemdir'), delete=False).name
        tmppdf = tempfile.NamedTemporaryFile(
            mode='w', prefix='report-', suffix='.pdf',
            dir=self._args.get('strmemdir'), delete=False).name

        # Copy in the main boiler plate
        repsrc = os.path.join(self._args.get('strmemdir'), 'report-header.md')
        try:
            shutil.copyfile(repsrc, tmpmd)
        except Exception as e:
            ename=type(e).__name__
            self._log.error(
                f'ERROR: Unable to copy header {repsrc} to {tmpmd}: {ename}')
            return None

        # Now open to append the specifics
        with open(tmpmd, mode="a", encoding="utf-8") as fh:
            datestamp = self._args.get('datestamp')
            user = os.getlogin()
            fh.write(f'- Datestamp: {datestamp}\n')
            fh.write(f'- User: {user}\n\n')
            fh.write('## Functions to be benchmarked\n\n')
            fh.write('Any functions which failed to benchmark are noted.\n\n')
            for bm in self._args.get('bmlist'):
                if bm in omitlist:
                    fh.write(f'- {bm} **(failed)**\n\n')
                else:
                    fh.write(f'- {bm}\n\n')
            fh.write('## QEMU versions\n\n')
            for cmt in self._args.get('qemulist'):
                fh.write(f'- {cmt}\n\n')
            fh.write('## Tool chain configuration\n\n')
            fh.write('GCC configuration\n')
            self._report_version('riscv64-unknown-linux-gnu-gcc -v', fh, 105)
            fh.write('Assembler version\n')
            self._report_version('riscv64-unknown-linux-gnu-as -v < /dev/null',
                                 fh, 105)
            fh.write('Linker version\n')
            self._report_version('riscv64-unknown-linux-gnu-ld -v', fh, 105)
            fh.write('Glibc version\n')
            ldd = os.path.join(self._args.get('installdir'), 'sysroot', 'usr',
                                              'bin', 'ldd')
            self._report_version(f'{ldd} --version -v', fh, 105)

        # Use pandoc to create the PDF file.
        cmd = f'pandoc -s -V geometry:landscape {tmpmd} -o {tmppdf}'
        try:
            res = subprocess.run(
                cmd,
                shell=True,
                executable='/bin/bash',
                cwd=self._args.get('strmemdir'),
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=self._args.get('timeout'),
                check=True,
            )
        except subprocess.TimeoutExpired as e:
            self._log.error('ERROR: Pandoc timed out.')
            self._log.debug(e.cmd)
            self._log.debug(e.stdout)
            self._log.debug(e.stderr)
            return None
        except subprocess.CalledProcessError as e:
            self._log.error('ERROR: Pandoc failed.')
            self._log.debug(e.cmd)
            self._log.debug(e.stdout)
            return None
        else:
            if res.returncode == 0:
                return tmppdf

            return None
        finally:
            # The markdown file can now be deleted.
            try:
                os.remove(tmpmd)
            except Exception as e:
                self._log.debug(
                    'Debug: Unable to delete temporary Markdown {tmpmd}')

    def _plotpdf(self, bm):
        """Generate graph for the specified benchmark.  Return the PDF file
           generated on success, or None on failure."""
        cmtlist = self._args.get('qemulist')
        oldqemu = cmtlist[0]
        newqemu = cmtlist[1]
        conflist = self._args.get('conflist')
        conf1 = conflist[0]
        conf2 = conflist[1]
        conf3 = conflist[2]
        plotcmd=os.path.join(self._args.get('strmemdir'),
                             'plot-one-benchmark.sh')
        cmd = f'{plotcmd} --benchmark "{bm}" ' \
            f'--old-qemu "baseline (#{oldqemu}))" ' \
            f'--new-qemu "latest (#{newqemu})" ' \
	    f'--old-scalar-data "{self.results[oldqemu][bm][conf1]}" ' \
	    f'--new-scalar-data "{self.results[newqemu][bm][conf1]}" ' \
	    f'--old-small-vector-data "{self.results[oldqemu][bm][conf2]}" ' \
	    f'--new-small-vector-data "{self.results[newqemu][bm][conf2]}" ' \
	    f'--old-large-vector-data "{self.results[oldqemu][bm][conf3]}" ' \
	    f'--new-large-vector-data "{self.results[newqemu][bm][conf3]}"'
        try:
            res = subprocess.run(
                cmd,
                shell=True,
                executable='/bin/bash',
                cwd=self._args.get('strmemdir'),
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=self._args.get('timeout'),
                check=True,
            )
        except subprocess.TimeoutExpired as e:
            self._log.error(f'ERROR: Plotting {bm} timed out.')
            self._log.debug(e.cmd)
            self._log.debug(e.stdout)
            self._log.debug(e.stderr)
            return None
        except subprocess.CalledProcessError as e:
            self._log.error(f'ERROR: Plotting {bm} failed.')
            self._log.debug(e.cmd)
            self._log.debug(e.stdout)
            return None

        if res.returncode != 0:
            self._log.error(f'ERROR: Plotting {bm} failed: {res}.')
            self._log.debug(cmd)
            self._log.debug(res.stdout.decode('utf-8'))
            self._log.debug(res.stderr.decode('utf-8'))
            return None

        return os.path.join(self._args.get('strmemdir'), 'graphs', f'{bm}.pdf')

    def gen_report(self):
        """Generate the report.  For now we only report with two QEMU commits
           and three configs ."""
        self._log.info('Generating report')
        if len(self._args.get('qemulist')) != 2:
            self._log.warning('Warning: Can only report with two QEMU commits.')
            return False
        if len(self._args.get('conflist')) != 3:
            self._log.warning('Warning: Can only report with three configs.')
            return False

        # Create all the graphs.
        plotlist = []
        omitlist = []

        cmtlist = self._args.get('qemulist')
        conflist = self._args.get('conflist')
        for bm in self._args.get('bmlist'):
            canplot = True
            for cmt in cmtlist:
                for conf in conflist:
                    if not self.results[cmt][bm][conf]:
                        canplot = False
            if canplot:
                plotpdf = self._plotpdf(bm)
                if plotpdf:
                    plotlist.append(plotpdf)
                    print('.', end='', flush=True)
            else:
                omitlist.append(bm)
                self._log.warning(f'\nWarning: Unable to plot for {bm}')

        print()

        # Create a PDF with the main file.
        tmppdf = self._report_main(omitlist)

        # Combine all the PDFs
        reportname = 'report-' + self._args.get('datestamp') + '.pdf'
        reportfile = os.path.join(self._args.get('strmemdir'), reportname)
        if tmppdf:
            pdflist = f'{tmppdf} ' + ' '.join(plotlist)
        else:
            pdflist = ' '.join(plotlist)
        cmd = f'gs -dNOPAUSE -sDEVICE=pdfwrite -dBATCH ' \
	    f'-sOUTPUTFILE="{reportfile}" {pdflist}'
        try:
            res = subprocess.run(
                cmd,
                shell=True,
                executable='/bin/bash',
                cwd=self._args.get('strmemdir'),
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=self._args.get('timeout'),
                check=True,
            )
        except subprocess.TimeoutExpired as e:
            self._log.error('ERROR: PDF combining timed out.')
            self._log.debug(e.cmd)
            self._log.debug(e.stdout)
            self._log.debug(e.stderr)
            return False
        except subprocess.CalledProcessError as e:
            self._log.error('ERROR: PDF combining failed.')
            self._log.debug(e.cmd)
            self._log.debug(e.stdout)
            return False

        if res.returncode != 0:
            self._log.error('ERROR: PDF combining failed.')
            self._log.debug(cmd)
            return False

        self._log.info(f'Report in {reportfile}')

        # Clean up
        try:
            if tmppdf:
                os.remove(tmppdf)
        except Exception as e:
            self._log.debug(
                'Debug: Unable to delete temporary PDF {tmppdf}')

        return True
