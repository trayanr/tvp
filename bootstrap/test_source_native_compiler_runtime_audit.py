"""Compiler runtime boundaries must fail closed independently of graph membership."""
import importlib
import unittest

observer = importlib.import_module('source-native-compiler-runtime-audit')


class Boundaries(unittest.TestCase):
    def test_no_empty_proof(self):
        with self.assertRaises(ValueError): observer.validate_maps([], {'/nix/store/native'})

    def test_old_tool_generation_is_not_compiler_permission(self):
        with self.assertRaises(ValueError):
            observer.validate_maps(['/nix/store/old-libc/lib/libc.so.6'], {'/nix/store/native-libc'})

    def test_failed_construction_is_required(self):
        with self.assertRaisesRegex(ValueError, 'Construction'):
            observer.run({'failures': ['unclassified input']})


if __name__ == '__main__': unittest.main()
