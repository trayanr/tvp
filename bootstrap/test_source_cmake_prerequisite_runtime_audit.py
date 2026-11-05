"""New boundary controls: development references never authorize native ELF."""
import importlib
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

observer = importlib.import_module('source-cmake-prerequisite-runtime-audit')


class Boundary(unittest.TestCase):
    def test_development_compiler_rpath_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / 'extension.so'
            p.write_bytes(b'\x7fELF')
            text = ('Advanced Micro Devices X86-64\n'
                    ' (RUNPATH) Library runpath: [/nix/store/compiler/lib]\n')
            with patch.object(subprocess, 'check_output', return_value=text):
                files, failures = observer.scan([d], {d}, d+'/ld', 'readelf')
            self.assertTrue(any('Foreign search' in f for f in failures))
            self.assertEqual(len(files), 1)

    def test_other_loader_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / 'perl'
            p.write_bytes(b'\x7fELF')
            text = ('Advanced Micro Devices X86-64\n'
                    '[Requesting program interpreter: /lib/ld-musl-x86_64.so.1]\n')
            result = subprocess.CompletedProcess([], 1, 'unavailable')
            with patch.object(subprocess, 'check_output', return_value=text), patch.object(subprocess, 'run', return_value=result):
                _, failures = observer.scan([d], {d}, d+'/ld', 'readelf')
            self.assertTrue(any('Foreign interpreter' in f for f in failures))


if __name__ == '__main__':
    unittest.main()
