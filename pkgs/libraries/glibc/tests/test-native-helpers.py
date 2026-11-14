"""Bounded filesystem contracts; pass native directory and TVP_TEST_BASH.

No compiler or canonical libc is executed.
"""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

NATIVE = Path(sys.argv.pop(1))
sys.path.insert(0, str(NATIVE))
from prepare import private_files  # noqa: E402


class PrivateTree(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.outside = self.root / 'outside'
        self.outside.write_bytes(b'untouched')
        self.tree = self.root / 'tree'
        self.tree.mkdir()

    def test_regular_and_discovered_symlinks(self):
        (self.tree / 'regular').write_bytes(b'owned')
        (self.tree / 'link').symlink_to(self.outside)
        self.assertEqual(private_files(self.tree), [self.tree / 'regular'])

    def test_symlink_parent(self):
        (self.root / 'alias').symlink_to(self.tree, target_is_directory=True)
        (self.tree / 'nested').mkdir()
        with self.assertRaisesRegex(ValueError, 'symlink parent'):
            private_files(self.root / 'alias' / 'nested')

    def test_hardlink_escape(self):
        os.link(self.outside, self.tree / 'escape')
        with self.assertRaisesRegex(ValueError, 'non-private'):
            private_files(self.tree)
        self.assertEqual(self.outside.read_bytes(), b'untouched')

    def test_source_preparation_still_rejects_linked_elf(self):
        self.outside.write_bytes(b'\x7fELFunchanged')
        os.link(self.outside, self.tree / 'linked-elf')
        with self.assertRaisesRegex(ValueError, 'non-private'):
            private_files(self.tree)
        self.assertEqual(self.outside.read_bytes(), b'\x7fELFunchanged')

    def run_rebind(self, *args):
        return subprocess.run([sys.executable, '-B', str(NATIVE / 'rebind-tools.py'),
                               str(self.tree), sys.executable, sys.executable,
                               '/old/perl', '/declared/bin', *args], capture_output=True)

    def test_prepare_rejection_preserves_whole_tree(self):
        (self.tree / 'elf').mkdir()
        (self.tree / 'elf/rtld.c').write_bytes(b'"/etc/ld.so.preload"\n')
        (self.tree / 'a-script').write_bytes(b'#!/bin/sh\necho original\n')
        (self.tree / 'z-script').write_bytes(b'#!/bin/sh')

        def snapshot():
            return {str(p.relative_to(self.tree)): (p.read_bytes(), p.stat().st_mode,
                                                    p.stat().st_mtime_ns)
                    for p in self.tree.rglob('*') if p.is_file()}

        before = snapshot()
        result = subprocess.run([sys.executable, '-B', str(NATIVE / 'prepare.py'),
                                 str(self.tree), '/selected/libc', os.environ['TVP_TEST_BASH']],
                                capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b'unterminated script directive', result.stderr)
        self.assertEqual(snapshot(), before)

    def test_prepare_commits_valid_replacements(self):
        (self.tree / 'elf').mkdir()
        rtld = self.tree / 'elf/rtld.c'
        rtld.write_bytes(b'"/etc/ld.so.preload"\n')
        script = self.tree / 'script'
        script.write_bytes(b'#!/bin/sh\necho original\n')
        script.chmod(0o755)
        os.utime(script, (1234567890, 1234567890))
        shell = os.environ['TVP_TEST_BASH']
        subprocess.run([sys.executable, '-B', str(NATIVE / 'prepare.py'),
                        str(self.tree), '/selected/libc', shell], check=True)
        self.assertEqual(rtld.read_bytes(), b'"/selected/libc/etc/ld.so.preload"\n')
        self.assertEqual(script.read_bytes(), b'#!' + os.fsencode(shell) + b'\necho original\n')
        self.assertEqual(script.stat().st_mtime, 1234567890)
        self.assertEqual(script.stat().st_mode & 0o777, 0o755)

    def test_rebind_rejects_before_any_write(self):
        first = self.tree / 'a-script'
        first.write_bytes(b'#!/bin/sh\necho ok\n')
        first.chmod(0o755)
        os.link(self.outside, self.tree / 'z-escape')
        result = self.run_rebind()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b'non-private', result.stderr)
        self.assertEqual(first.read_bytes(), b'#!/bin/sh\necho ok\n')
        self.assertEqual(self.outside.read_bytes(), b'untouched')

    def test_rebind_preserves_elf_links_across_output_roots(self):
        self.outside.write_bytes(b'\x7fELFunchanged-getconf')
        self.outside.chmod(0o755)
        paths = [self.outside, self.tree / 'getconf', self.tree / 'getconf-alias',
                 self.root / 'other-output-alias']
        for path in paths[1:]:
            os.link(self.outside, path)
        script = self.tree / 'ldd'
        script.write_bytes(b'#!/bin/sh\necho original\n')
        script.chmod(0o755)

        def snapshot():
            return [(p.read_bytes(), p.stat().st_dev, p.stat().st_ino,
                     p.stat().st_nlink, p.stat().st_mode, p.stat().st_mtime_ns)
                    for p in paths]

        before = snapshot()
        result = self.run_rebind()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(snapshot(), before)
        self.assertEqual(self.outside.stat().st_nlink, 4)
        self.assertNotEqual(script.read_bytes(), b'#!/bin/sh\necho original\n')

    def test_unsupported_directive_has_no_partial_write(self):
        first = self.tree / 'a-script'
        first.write_bytes(b'#!/bin/sh\necho ok\n')
        first.chmod(0o755)
        second = self.tree / 'z-script'
        second.write_bytes(b'#!/bin/sh -e\necho unsafe\n')
        second.chmod(0o755)
        self.assertNotEqual(self.run_rebind().returncode, 0)
        self.assertEqual(first.read_bytes(), b'#!/bin/sh\necho ok\n')

    def test_repeated_shell_rebinding_updates_auxiliary_path(self):
        script = self.tree / 'ldd'
        script.write_bytes(b'#!/bin/sh\necho original\n')
        script.chmod(0o755)
        # Use an actual shell name so a second invocation recognizes it.
        # The selected current environment provides Bash via its real path.
        shell = os.environ['TVP_TEST_BASH']
        command = [sys.executable, '-B', str(NATIVE / 'rebind-tools.py'),
                   str(self.tree), shell, sys.executable, '/old/perl']
        subprocess.run([*command, '/first/bin'], check=True)
        subprocess.run([*command, '/second/bin'], check=True)
        data = script.read_bytes()
        self.assertNotIn(b'/first/bin', data)
        self.assertEqual(data.count(b"export PATH='/second/bin'"), 1)
        self.assertTrue(data.endswith(b'echo original\n'))

    def test_mtrace_fallback_elf_symlinks_and_times(self):
        mtrace = self.tree / 'mtrace'
        mtrace.write_bytes(b'#! /old/perl\neval "exec /old/perl -S $0 $@"\n    if 0;\n')
        mtrace.chmod(0o755)
        os.utime(mtrace, (1234567890, 1234567890))
        elf = self.tree / 'elf'
        elf.write_bytes(b'\x7fELFunchanged')
        elf.chmod(0o755)
        (self.tree / 'link').symlink_to(mtrace.name)
        result = self.run_rebind()
        self.assertEqual(result.returncode, 0, result.stderr)
        data = mtrace.read_bytes()
        self.assertTrue(data.startswith(b'#!' + os.fsencode(sys.executable) + b'\n'))
        self.assertIn(b'eval "exec ' + os.fsencode(sys.executable) + b' -S $0 $@"', data)
        self.assertNotIn(b'/old/perl', data)
        self.assertEqual(mtrace.stat().st_mtime, 1234567890)
        self.assertEqual(mtrace.stat().st_mode & 0o777, 0o755)
        self.assertEqual(elf.read_bytes(), b'\x7fELFunchanged')
        self.assertEqual(os.readlink(self.tree / 'link'), 'mtrace')

    def test_identical_mtrace_rebinding_is_idempotent(self):
        selected = self.root / 'selected-perl'
        selected.mkdir()
        perl = selected / 'perl'
        perl.symlink_to(sys.executable)
        script = self.tree / 'mtrace'
        script.write_bytes(b'#!/old/perl\neval "exec /old/perl -S $0 $@"\n    if 0;\n')
        script.chmod(0o755)
        command = [sys.executable, '-B', str(NATIVE / 'rebind-tools.py'), str(self.tree),
                   os.environ['TVP_TEST_BASH'], str(perl), '/old/perl', '/declared/bin']
        subprocess.run(command, check=True)
        before = script.read_bytes(), script.stat().st_ctime_ns
        subprocess.run(command, check=True)
        self.assertEqual((script.read_bytes(), script.stat().st_ctime_ns), before)
        self.assertIn(b'eval "exec ' + os.fsencode(perl) + b' -S $0 $@"', before[0])

    def test_ambiguous_mtrace_fallback_preserves_all_scripts(self):
        first = self.tree / 'a-script'
        first.write_bytes(b'#!/bin/sh\necho original\n')
        first.chmod(0o755)
        script = self.tree / 'mtrace'
        data = (b'#!/old/perl\neval "exec /old/perl -S $0 $@"\n'
                + b'eval "exec ' + os.fsencode(sys.executable) + b' -S $0 $@"\n')
        script.write_bytes(data)
        script.chmod(0o755)
        result = self.run_rebind()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b'expected configured mtrace Perl fallback', result.stderr)
        self.assertEqual(first.read_bytes(), b'#!/bin/sh\necho original\n')
        self.assertEqual(script.read_bytes(), data)


if __name__ == '__main__':
    unittest.main()
