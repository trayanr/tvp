"""Focused object classification and the two-manual operation."""
import gzip
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ELF, OLD, MAN, BINUTILS, PATCHELF, GZIP, CC = sys.argv[1:]
sys.argv[1:] = []


def command(*args):
    return subprocess.run(list(map(str, args)), check=True, capture_output=True).stdout


class RubyOutput(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        self.root = self.work / 'out'
        (self.root / 'lib').mkdir(parents=True)
        self.config = dict(paths=['lib'], readelf=f'{BINUTILS}/bin/readelf',
                           strip=f'{BINUTILS}/bin/strip', flags=['-S', '-p'],
                           patchelf=f'{PATCHELF}/bin/patchelf', dlopenDirectories=[])
        self.source = self.work / 'probe.c'
        self.source.write_text('int answer(void) { return 42; }\n')

    def step(self, operation, kinds, success=True, **options):
        result = subprocess.run([sys.executable, '-B', ELF, str(self.root),
                                 json.dumps(self.config | dict(kinds=kinds) | options),
                                 OLD, operation], capture_output=True)
        self.assertEqual(result.returncode == 0, success, result.stderr.decode())

    def test_object_strips_links_and_never_reaches_patchelf(self):
        obj = self.root / 'lib' / 'probe.o'
        command(CC, '-g', '-c', self.source, '-o', obj)
        self.assertIn(b'.debug_info', command(self.config['readelf'], '-S', obj))
        self.step('strip', ['runtime', 'relocatable'])
        self.assertNotIn(b'.debug_info', command(self.config['readelf'], '-S', obj))
        for operation in ['rpaths', 'check-paths']:
            self.step(operation, ['runtime'], patchelf='/does/not/exist')
        main = self.work / 'main.c'
        main.write_text('int answer(void); int main(void) { return answer() != 42; }')
        command(CC, main, obj, '-o', self.work / 'consumer')
        command(self.work / 'consumer')

    def test_runtime_and_malformed_errors_stay_errors(self):
        dynamic = self.root / 'lib' / 'probe.so'
        command(CC, '-g', '-shared', '-fPIC', self.source, '-o', dynamic)
        self.step('rpaths', ['runtime'], success=False, patchelf='/does/not/exist')
        self.step('strip', ['runtime'], success=False, strip='/does/not/exist')
        dynamic.write_bytes(b'\x7fELF' + b'\0' * 20)
        self.step('rpaths', ['runtime'], success=False)
        self.step('strip', ['relocatable'], success=False)
        self.step('rpaths', ['relocatable'], success=False)

    def test_malformed_object_and_unsafe_paths(self):
        obj = self.root / 'lib' / 'probe.o'
        command(CC, '-g', '-c', self.source, '-o', obj)
        obj.write_bytes(obj.read_bytes()[:64])
        self.step('rpaths', ['runtime'], success=False)
        self.step('strip', ['relocatable'], success=False, paths=['../out'])

    def manuals(self):
        d = self.root / 'share' / 'man' / 'man1'
        d.mkdir(parents=True)
        for n in ['erb.1', 'ruby.1']:
            p = d / n
            p.write_bytes(b'.TH RUBY 1\ncontent\n')
            p.chmod(0o640)
            os.utime(p, (1700000000, 1700000000))
        return d

    def test_manual_bytes_modes_and_failure(self):
        d = self.manuals()
        expected = command(GZIP, '-c', '-n', d / 'ruby.1')
        command(sys.executable, MAN, self.root, GZIP)
        for p in d.iterdir():
            self.assertEqual(p.read_bytes(), expected)
            self.assertEqual(gzip.decompress(expected), b'.TH RUBY 1\ncontent\n')
            self.assertEqual(p.stat().st_mode & 0o777, 0o640)
            self.assertEqual(p.stat().st_mtime, 1700000000)
        self.assertEqual(len(list(d.iterdir())), 2)
        command(sys.executable, MAN, self.root, GZIP)
        self.assertEqual((d / 'erb.1.gz').read_bytes(), expected)

    def test_manual_failure_and_external_link(self):
        d = self.manuals()
        result = subprocess.run([sys.executable, MAN, str(self.root), '/does/not/exist'], capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue((d / 'erb.1').exists())
        outside = self.work / 'external'
        outside.write_text('untouched')
        (d / 'erb.1').unlink()
        (d / 'erb.1').symlink_to(outside)
        result = subprocess.run([sys.executable, MAN, str(self.root), GZIP], capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(outside.read_text(), 'untouched')


unittest.main(verbosity=2)
