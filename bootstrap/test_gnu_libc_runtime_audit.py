"""Rejections specific to exact staged generations; old tests stay unchanged."""
import importlib
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

observer = importlib.import_module('gnu-libc-runtime-audit')


class Generations(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.a, self.b, self.data = [Path(self.tmp.name) / n for n in ['new', 'old', 'data']]
        for root in [self.a, self.b, self.data]:
            root.mkdir()
        for root in [self.a, self.b]:
            (root / 'ld.so').write_bytes(b'loader')
        head = bytearray(64)
        head[:6] = b'\x7fELF\x02\x01'
        struct.pack_into('<H', head, 18, 62)
        (self.a / 'tool').write_bytes(head)
        self.report = dict(schema=1, failures=[], sourceData={str(self.data): dict(origin='owned-source-or-nix-generated-text')},
            runtimeForbiddenExecutableRoots=[], nodes={str(p): dict(origin='source-built-stage', outputs={'out': {'path': str(p)}}) for p in [self.a, self.b]})
        self.profile = dict(roots=[str(self.a)], readelf='observer-readelf', data=[str(self.data)], generations={
            n: dict(loader=str(p / 'ld.so'), executables=[str(p)], search=[str(p)])
            for n, p in [('new', self.a), ('old', self.b)]})
        self.closure = {str(p) for p in [self.a, self.b, self.data]}
        # Origin-schema predicates are independently tested by the unchanged
        # strict suite. Here temporary filesystem roots model classified outputs.
        for target, value in [('executable_outputs', {str(self.a), str(self.b)}),
                              ('origin_paths', dict.fromkeys(self.closure))]:
            patched = patch.object(observer.strict, target, return_value=value)
            patched.start()
            self.addCleanup(patched.stop)

    def audit(self, interp=None, search=None, actual=None, direct=None):
        info = 'Requesting program interpreter: ' + str(interp or self.a / 'ld.so') + ']\n'
        if search:
            info += '(RUNPATH) [' + search + ']\n'
        if direct:
            info += '(NEEDED) [ld.so]\n'
        output = '' if actual is None else 'libc.so.6 => ' + actual + ' (0x123)\n'
        if direct:
            output += direct + ' (0x123)\n'
        with patch.object(observer.subprocess, 'check_output', return_value=info), patch.object(
                observer.subprocess, 'run', return_value=type('Result', (), {'returncode': 0, 'stdout': output})()):
            return observer.audit(self.report, self.profile, self.closure)

    def test_correct_generations(self):
        self.assertEqual(self.audit()['failures'], [])

    def test_other_valid_generation_loader_rejected(self):
        self.assertTrue(any('interpreter' in s for s in self.audit(interp=self.b / 'ld.so')['failures']))

    def test_other_generation_search_rejected(self):
        self.assertTrue(any('search' in s for s in self.audit(search=str(self.b))['failures']))

    def test_actual_loader_cross_generation_rejected(self):
        self.assertTrue(any('actual loader' in s for s in self.audit(actual=str(self.b / 'ld.so'))['failures']))

    def test_direct_loader_needed_resolution(self):
        self.assertEqual(self.audit(direct=str(self.a / 'ld.so'))['failures'], [])

    def test_foreign_direct_loader_rejected(self):
        self.assertTrue(any('Foreign direct loader' in s for s in self.audit(direct=str(self.b / 'ld.so'))['failures']))

    def test_data_does_not_authorize_executable(self):
        self.profile['generations']['new']['executables'].append(str(self.data))
        with self.assertRaisesRegex(ValueError, 'data-only'):
            observer.validate(self.report, self.profile, self.closure)

    def test_extra_closure_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Closure differs'):
            observer.validate(self.report, self.profile, self.closure | {'/foreign'})

    def test_ambiguous_generation_rejected(self):
        self.profile['generations']['old']['executables'].append(str(self.a))
        with self.assertRaisesRegex(ValueError, 'Ambiguous'):
            observer.validate(self.report, self.profile, self.closure)

    def test_origin_expansion_stays_in_generation(self):
        self.assertEqual(self.audit(search='$ORIGIN')['failures'], [])
        self.assertTrue(any('search' in s for s in self.audit(search='$ORIGIN/../old')['failures']))
        self.assertTrue(any('search' in s for s in self.audit(search='$LIB')['failures']))

    def test_foreign_loader_rejected(self):
        self.profile['generations']['new']['loader'] = '/bin/sh'
        with self.assertRaisesRegex(ValueError, 'Loader outside'):
            observer.validate(self.report, self.profile, self.closure)

    def test_elf_in_data_rejected(self):
        (self.data / 'elf').write_bytes((self.a / 'tool').read_bytes())
        self.assertTrue(any('ELF in data' in s for s in self.audit()['failures']))


if __name__ == '__main__':
    unittest.main()
