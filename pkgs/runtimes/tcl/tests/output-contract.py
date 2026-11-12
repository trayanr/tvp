"""Tiny installed-layout and generated-Makefile controls; no Tcl or compiler runs."""
import importlib.util
import os
from pathlib import Path
import runpy
import struct
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('tcl_relocate', ROOT / 'relocate.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
runner = runpy.run_path(str(ROOT / 'tests/run-native.py'))


class Output(unittest.TestCase):
    def test_compiled_constants_and_installed_interfaces(self):
        with tempfile.TemporaryDirectory() as work:
            root = Path(work, 'final'); root.mkdir()
            old = os.fsencode(Path(work, 'prior'))
            new = os.fsencode(root)
            for directory in ('bin', 'lib', 'include', 'share', 'man'):
                (root / directory).mkdir()
            binary = root / 'lib/libtcl.so'
            # Tcl's compiled prefix and adjacent length/offset values must retain
            # their width. The remaining binary payload must stay byte-identical.
            constants = struct.pack('<II', len(old), 123456)
            binary.write_bytes(b'\x7fELF\0' + constants + old + b'/lib/tcl8.6\0tail')
            binary.chmod(0o755)
            stamp = binary.stat().st_mtime_ns
            config = root / 'lib/tclConfig.sh'
            config.write_bytes(b"TCL_INCLUDE_SPEC='-I" + old + b"/include'\n")
            (root / 'bin/tclsh8.6').write_bytes(b'payload')
            (root / 'bin/tclsh').symlink_to('tclsh8.6')
            (root / 'lib/self').symlink_to(os.fsdecode(old) + '/lib/libtcl.so')
            (root / 'lib/external').symlink_to('/other/provider')
            module.relocate(root, old)
            self.assertEqual(binary.read_bytes(), b'\x7fELF\0' + constants + new + b'/lib/tcl8.6\0tail')
            self.assertEqual(binary.stat().st_mode & 0o777, 0o755)
            self.assertEqual(binary.stat().st_mtime_ns, stamp)
            self.assertIn(new + b'/include', config.read_bytes())
            self.assertEqual(os.readlink(root / 'bin/tclsh'), 'tclsh8.6')
            self.assertEqual(os.readlink(root / 'lib/self'), str(root / 'lib/libtcl.so'))
            self.assertEqual(os.readlink(root / 'lib/external'), '/other/provider')

    def test_width_mismatch_rejected(self):
        with tempfile.TemporaryDirectory() as work:
            root = Path(work); (root / 'lib').mkdir()
            file = root / 'lib/tclConfig.sh'; file.write_bytes(b'original')
            with self.assertRaises(ValueError):
                module.relocate(root, b'/short')
            self.assertEqual(file.read_bytes(), b'original')

    def test_installed_core_and_stub_prerequisites(self):
        with tempfile.TemporaryDirectory() as work:
            prefix = Path(work, 'installed'); (prefix / 'lib').mkdir(parents=True)
            for name in ('libtcl8.6.so', 'libtclstub8.6.a'):
                (prefix / 'lib' / name).write_bytes(b'unchanged')
            (prefix / 'lib/tclConfig.sh').write_text(
                f"TCL_LIB_SPEC='-L{prefix}/lib -ltcl8.6'\nTCL_STUB_LIB_SPEC='-L{prefix}/lib -ltclstub8.6'\n")
            fixture = Path(work, 'fixture'); (fixture / 'dltest').mkdir(parents=True)
            (fixture / 'tclConfig.sh').write_text(
                "TCL_BUILD_LIB_SPEC='-L/private -ltcl8.6'\nTCL_BUILD_STUB_LIB_SPEC='-L/private -ltclstub8.6'\n")
            (fixture / 'Makefile').write_text(
                'TCL_LIB_FILE = libtcl8.6.so\nTCL_STUB_LIB_FILE = libtclstub8.6.a\n'
                'link: ; cc -L/private -ltcl8.6\nrecursive: ; make tcltest-real LIB_RUNTIME_DIR="`pwd`"\n')
            (fixture / 'dltest/Makefile').write_text('LIBS = -L/private -ltclstub8.6\n')
            previous, argv = Path.cwd(), sys.argv
            try:
                os.chdir(fixture); sys.argv = ['prepare-native.py', str(prefix)]
                runpy.run_path(str(ROOT / 'tests/prepare-native.py'), run_name='__main__')
            finally:
                os.chdir(previous); sys.argv = argv
            text = (fixture / 'Makefile').read_text()
            self.assertNotIn('/private', text)
            for name in ('libtcl8.6.so', 'libtclstub8.6.a'):
                self.assertIn(str(prefix / 'lib' / name), text)
                self.assertEqual((prefix / 'lib' / name).read_bytes(), b'unchanged')
            self.assertNotIn('/private', (fixture / 'dltest/Makefile').read_text())
            self.assertEqual(len((fixture / 'fixture-libraries').read_text().splitlines()), 2)

    def test_real_summary_failures_remain_failures(self):
        runner['summary']('Total 10 Passed 8 Skipped 2 Failed 0')
        for log in ('Total 10 Passed 8 Skipped 1 Failed 1', 'Total 0 Passed 0 Skipped 0 Failed 0',
                    'Total 10 Passed 8 Skipped 2 Failed 0\nTest file error: broken',
                    'Total 10 Passed 8 Skipped 2 Failed 0\n==== fixture FAILED'):
            with self.assertRaises(ValueError):
                runner['summary'](log)


if __name__ == '__main__':
    unittest.main()
