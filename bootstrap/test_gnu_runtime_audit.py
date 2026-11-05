"""Negative contracts for the separate strict GNU runtime profile."""
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('gnu_audit', sys.argv.pop(1))
a = importlib.util.module_from_spec(spec)
spec.loader.exec_module(a)


class GNUAuditTests(unittest.TestCase):
    def test_source_data_never_authorizes_executable(self):
        stage = '/nix/store/' + 'a' * 32 + '-stage'
        source = '/nix/store/' + 'b' * 32 + '-source'
        report = dict(schema=1, failures=[], nodes={'drv': {
            'origin': 'source-built-stage', 'outputs': {'out': {'path': stage}}}},
            sourceData={source: {'origin': 'owned-source-or-nix-generated-text'}},
            runtimeForbiddenExecutableRoots=[])
        self.assertEqual(a.executable_outputs(report), {stage})
        self.assertNotIn(source, a.executable_outputs(report))

    def test_incidental_closure_library_is_not_search_resolution(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            lib = root / 'lib'
            lib.mkdir()
            (lib / 'libgcc_s.so.1').write_bytes(b'fixture')
            self.assertIsNone(a.resolve_needed('libgcc_s.so.1', [], {temp}, {temp}))
            self.assertEqual(a.resolve_needed('libgcc_s.so.1', [str(lib)], {temp}, {temp}), str(lib / 'libgcc_s.so.1'))
            self.assertIsNone(a.resolve_needed('libgcc_s.so.1', [str(lib)], {temp}, set()))

    def test_owned_musl_loader_still_fails_gnu_profile(self):
        with tempfile.TemporaryDirectory() as temp:
            m = Path(temp) / 'libc.so'
            g = Path(temp) / 'ld-linux-x86-64.so.2'
            m.write_bytes(b'fixture')
            g.write_bytes(b'fixture')
            self.assertFalse(a.gnu_interpreter(str(m), str(g), {temp}))
            self.assertTrue(a.gnu_interpreter(str(g), str(g), {temp}))

    def test_dependency_name_cannot_escape_search_directory(self):
        for name in ['/lib/libc.so.6', '../libc.so.6', '', '.', '..']:
            self.assertIsNone(a.resolve_needed(name, ['/lib'], {'/lib'}, {'/lib'}))


if __name__ == '__main__':
    unittest.main(verbosity=2)
