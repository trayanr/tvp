"""The legacy adapter preserves comments and rejects unexpected interpreters."""
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    'legacy_configure', Path(__file__).resolve().parents[1] / 'normalize-legacy-configure.py'
)
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class LegacyConfigureTests(unittest.TestCase):
    def check_case(self, original, expected=None):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'configure'
            path.write_bytes(original)
            path.chmod(0o755)
            os.utime(path, ns=(123456789000000000, 234567890000000000))
            before = path.stat()
            if expected is None:
                with self.assertRaises(ValueError):
                    helper.normalize_configure(path)
                expected = original
            else:
                helper.normalize_configure(path)
            self.assertEqual(path.read_bytes(), expected)
            self.assertEqual(path.stat().st_mtime_ns, before.st_mtime_ns)
            self.assertEqual(path.stat().st_mode, before.st_mode)

    def test_preserves_comment_prefix_as_body(self):
        prefix = b'\n# Forbidden tokens and exceptions.\n# Copyright Example\n\n'
        body = b'echo configured\n'
        self.check_case(prefix + b'#! /bin/sh\n' + body, b'#! /bin/sh\n' + prefix + body)

    def test_valid_first_line_is_unchanged(self):
        for header in (b'#!/bin/sh\n', b'#! /bin/sh\n', b'#!\t/bin/sh\n'):
            with self.subTest(header=header):
                self.check_case(header + b'echo configured\n', header + b'echo configured\n')

    def test_rejects_unexpected_prefix_without_mutation(self):
        for prefix in (
            b'echo executable\n',
            b'#!/usr/bin/python\n',
            b'\n#! /nix/store/unexpected/bin/bash\n',
            b'\n #! /bin/bash\n',
            b'# comment with NUL\0\n',
        ):
            with self.subTest(prefix=prefix):
                self.check_case(prefix + b'#! /bin/sh\necho configured\n')

    def test_rejects_missing_shell_header(self):
        self.check_case(b'\n# only comments\n')


if __name__ == '__main__':
    unittest.main()
