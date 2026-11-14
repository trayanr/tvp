"""Tiny installed-tree fixtures; no CPython, compiler or dependency build."""
import ast
import contextlib
import io
import runpy
import types
from unittest import mock
import importlib.util
import os
from pathlib import Path
import py_compile
import subprocess
import sys
import tempfile
import unittest

NATIVE = Path(__file__).resolve().parents[1] / 'native'
spec = importlib.util.spec_from_file_location('python_relocate', NATIVE / 'relocate.py')
relocator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(relocator)


class OutputHelpers(unittest.TestCase):
    def test_installed_constants_links_modes_and_times(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / 'final'
            root.mkdir()
            old = str(root).replace('final', 'prior').encode()
            payload = root / 'python'
            data = b'\x7fELF\0prefix=' + old + b'\0marshal=' + old + b'/lib\0'
            payload.write_bytes(data)
            payload.chmod(0o555)
            os.utime(payload, ns=(123456000000, 123456000000))
            os.link(payload, root / 'alias')
            (root / 'absolute').symlink_to(old.decode() + '/python')
            (root / 'relative').symlink_to('python')
            relocator.relocate(root, old)
            self.assertEqual(payload.read_bytes(), data.replace(old, os.fsencode(root)))
            self.assertEqual(payload.stat().st_ino, (root / 'alias').stat().st_ino)
            self.assertEqual(payload.stat().st_mode & 0o777, 0o555)
            self.assertEqual(payload.stat().st_mtime_ns, 123456000000)
            self.assertEqual(os.readlink(root / 'absolute'), str(root / 'python'))
            self.assertEqual(os.readlink(root / 'relative'), 'python')

    def test_reject_before_writing(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / 'final'
            root.mkdir()
            old = str(root).replace('final', 'prior').encode()
            payload = root / 'payload'
            payload.write_bytes(old)
            os.link(payload, Path(directory) / 'external')
            with self.assertRaisesRegex(ValueError, 'external installed hardlink'):
                relocator.relocate(root, old)
            self.assertEqual(payload.read_bytes(), old)
            with self.assertRaisesRegex(ValueError, 'equal-width'):
                relocator.relocate(root, b'/short')

    def test_legacy_linkage_parser(self):
        helper = NATIVE.parent / 'tests/native-linkage.py'
        # The linkage probe executes on every target, including Python 3.5.
        ast.parse(helper.read_text(), feature_version=(3, 5))
        fake = types.ModuleType('tvp_fixture')
        fake.__file__ = '/fixture/module.so'
        responses = ['Requesting program interpreter: /declared/loader]',
                     'libz.so.1 => /provider/lib/libz.so.1 (0x1234)']
        with mock.patch.dict(sys.modules, {'tvp_fixture': fake}), \
             mock.patch.object(sys, 'argv', [str(helper), '/provider/lib', r'libz\.so', 'tvp_fixture']), \
             mock.patch('subprocess.check_output', side_effect=responses), \
             contextlib.redirect_stdout(io.StringIO()) as output, \
             contextlib.redirect_stderr(io.StringIO()):
            runpy.run_path(str(helper), run_name='__main__')
        self.assertEqual(output.getvalue().strip(), 'linked')

    def test_target_bytecode_and_shebangs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'bin').mkdir()
            (root / 'bin/python3').symlink_to(sys.executable)
            library = root / 'lib/python3.12'
            library.mkdir(parents=True)
            source = library / 'subprocess.py'
            source.write_text('#!/prior/python\nshell = "/build/bash"\n')
            py_compile.compile(str(source), doraise=True)
            script = root / 'bin/pydoc3'
            script.write_text('#!/prior/python\nprint(42)\n')
            helpers = {
                root / 'lib/python3.12/ctypes/macholib/fetch_macholib': '#!/bin/sh',
                root / 'lib/python3.5/plat-linux/regen': '#! /bin/sh',
            }
            for helper, shebang in helpers.items():
                helper.parent.mkdir(parents=True, exist_ok=True)
                helper.write_text(shebang + '\nprintf fixture\\n\n')
                helper.chmod(0o755)
                os.utime(helper, ns=(123456000000, 123456000000))
            subprocess.run([sys.executable, '-B', str(NATIVE / 'install.py'),
                            str(root), '/build/bash', '/helpers',
                            '/build/bash', '/runtime/bash'], check=True)
            self.assertIn('shell = "/runtime/bash"', source.read_text())
            self.assertEqual(script.read_text().splitlines()[0], '#!' + str(root) + '/bin/python3')
            for helper in helpers:
                self.assertEqual(helper.read_text(), '#!/runtime/bash\nprintf fixture\\n\n')
                self.assertEqual(helper.stat().st_mode & 0o777, 0o755)
                self.assertEqual(helper.stat().st_mtime_ns, 123456000000)
            cache = next((library / '__pycache__').glob('subprocess.*.pyc'))
            self.assertEqual(cache.read_bytes()[8:16], importlib.util.source_hash(source.read_bytes()))


if __name__ == '__main__':
    unittest.main()
