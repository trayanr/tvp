"""Offline regressions for the bootstrap runtime observer."""
import copy
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('runtime_audit', sys.argv.pop(1))
a = importlib.util.module_from_spec(spec)
spec.loader.exec_module(a)


class RuntimeTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        self.root = self.directory / 'owned'
        (self.root / 'lib').mkdir(parents=True)
        self.outside = self.directory / 'foreign'
        self.outside.write_text('outside closure')
        self.paths = {str(self.root)}

    def test_bare_library_is_found_in_owned_closure(self):
        (self.root / 'lib' / 'libc.so').write_text('owned library fixture')
        self.assertTrue(a.owned_library('libc.so', self.paths))
        self.assertFalse(a.owned_library('missing.so', self.paths))

    def test_absolute_and_traversal_needed_cannot_use_host_files(self):
        for name in [str(self.outside), '/etc/passwd', '../foreign', './libc.so', '', '.', '..']:
            with self.subTest(name=name):
                self.assertFalse(a.owned_library(name, self.paths))

    def test_library_symlink_must_resolve_inside_classified_closure(self):
        link = self.root / 'lib' / 'libc.so'
        link.symlink_to(self.outside)
        self.assertFalse(a.owned_library('libc.so', self.paths))
        link.unlink()
        dependency = self.directory / 'dependency'
        (dependency / 'lib').mkdir(parents=True)
        target = dependency / 'lib' / 'libc.so'
        target.write_text('owned dependency fixture')
        link.symlink_to(target)
        self.assertTrue(a.owned_library('libc.so', self.paths | {str(dependency)}))

    def test_executable_path_cannot_escape_owned_roots(self):
        program = self.root / 'program'
        program.write_text('fixture')
        self.assertTrue(a.owned_executable(str(program), self.paths))
        self.assertFalse(a.owned_executable(str(self.root) + '/../foreign', self.paths))
        program.unlink()
        program.symlink_to(self.outside)
        self.assertFalse(a.owned_executable(str(program), self.paths))

    def test_failed_or_malformed_origin_report_rejects_before_nix(self):
        good = {'schema': 1, 'failures': [], 'sourceData': {}, 'runtimeForbiddenExecutableRoots': [], 'nodes': {
            'fixture.drv': {'origin': 'source-built-stage', 'outputs': {
                'out': {'path': '/nix/store/' + 'a' * 32 + '-fixture'}}}}}
        self.assertEqual(len(a.origin_paths(good)), 1)
        for change in [{'schema': 2}, {'failures': ['undeclared executable builder']},
                       {'failures': None}, {'nodes': {}}, {'sourceData': None},
                       {'runtimeForbiddenExecutableRoots': None},
                       {'runtimeForbiddenExecutableRoots': ['/unknown']}]:
            report = copy.deepcopy(good)
            report.update(change)
            with self.subTest(change=change), patch.object(a.subprocess, 'check_output') as command:
                with self.assertRaises(ValueError):
                    a.audit(report, '/unused/readelf', [str(self.root)])
                command.assert_not_called()

    def inspect_elf(self, machine=62, extra='', early=False):
        header = bytearray(64)
        header[:6] = b'\x7fELF\x02\x01'
        header[18:20] = machine.to_bytes(2, 'little')
        (self.root / 'program').write_bytes(header)
        # Source text mentioning a seed is harmless; native early programs aren't.
        (self.root / 'source.txt').write_text('source-only reference to hex0 seed')
        report = {'schema': 1, 'failures': [], 'sourceData': {},
                  'runtimeForbiddenExecutableRoots': [str(self.root)] if early else [],
                  'nodes': {'fixture.drv': {'origin': 'source-built-stage',
                            'outputs': {'out': {'path': str(self.root)}}}}}
        def command(args, **kwargs):
            if args[:2] == ['nix', 'path-info']:
                return json.dumps([{'path': str(self.root)}])
            return 'Machine: AMD x86-64 (wording may vary)\n' + extra
        with patch.object(a.subprocess, 'check_output', side_effect=command), \
             patch.object(a, 'origin_paths', return_value={str(self.root): 'source-built-stage'}):
            return a.audit(report, '/observer/readelf', [str(self.root)])

    def test_architecture_uses_numeric_elf_machine(self):
        result = self.inspect_elf()
        self.assertEqual(result['failures'], [])
        self.assertEqual(result['files'][str(self.root / 'program')]['machine'], 62)
        self.assertTrue(any('architecture' in f for f in self.inspect_elf(machine=3)['failures']))

    def test_runtime_search_paths_must_stay_in_owned_closure(self):
        for entry in ['/usr/lib', '/tmp/foreign', '', str(self.root) + '/../foreign']:
            with self.subTest(entry=entry):
                result = self.inspect_elf(extra=f'(RUNPATH) Library runpath: [{entry}]')
                self.assertTrue(any('runtime search path' in f for f in result['failures']))
        self.assertEqual(self.inspect_elf(extra=f'(RPATH) Library rpath: [{self.root}/lib]')['failures'], [])

    def test_early_executables_are_rejected_separately_from_source_text(self):
        self.assertEqual(self.inspect_elf()['failures'], [])
        self.assertTrue(any('early executable' in f for f in self.inspect_elf(early=True)['failures']))


if __name__ == '__main__':
    unittest.main(verbosity=2)
