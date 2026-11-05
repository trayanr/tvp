"""Offline argument contracts for both wrapper templates; no compiler is executed."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

BASH = sys.argv.pop(1)
RECIPES = Path(sys.argv.pop(1))


class WrapperTests(unittest.TestCase):
    def capture(self, template, args, store=''):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            compiler = root / 'capture'
            compiler.write_text('#!' + BASH + '\nprintf "%s\\0" "$@"\n')
            compiler.chmod(0o755)
            replacements = {
                'bash': BASH, 'gcc': str(compiler), 'origname': 'gcc',
                'origdir': '/nix/store/compiler/libexec/gcc', 'dynlinker': '/nix/store/musl/lib/libc.so',
                'libgcc': '/nix/store/compiler/lib/gcc/target/10.4.0',
                'libc': '/nix/store/musl/lib', 'gccinc': '/nix/store/compiler/include',
                'binutils': '/nix/store/binutils/bin', 'extraflags': '-static-libgcc',
                'libstdcxx': str(root / 'static-only'), 'libstdcxxinc': '/nix/store/compiler/include/c++',
                'libstdcxxarchinc': '/nix/store/compiler/include/c++/target',
            }
            text = (RECIPES / template).read_text()
            for key, value in replacements.items():
                text = text.replace('@' + key + '@', value)
            wrapper = root / 'wrapper'
            wrapper.write_text(text)
            result = subprocess.check_output([BASH, str(wrapper), *args], env={'NIX_STORE': store})
            return result.rstrip(b'\0').decode().split('\0')

    def test_empty_or_hostile_store_never_adds_host_rpaths(self):
        for template in ['wrapper.sh', 'wrappercxx.sh']:
            for store in ['', '/']:
                with self.subTest(template=template, store=store):
                    args = ['-L', '/tmp/outside lib', '-B/usr/bin', '/tmp/foreign.so', '-c', 'input with spaces.cc']
                    result = self.capture(template, args, store)
                    self.assertEqual(result[-len(args):], args)
                    self.assertEqual([a for a in result if a.startswith('-Wl,-rpath,')],
                                     ['-Wl,-rpath,/nix/store/musl/lib'])

    def test_store_rpath_and_caller_argv_boundaries(self):
        for template in ['wrapper.sh', 'wrappercxx.sh']:
            args = ['-L', '/nix/store/a dir/lib', '-B/nix/store/tools/bin', '/nix/store/other/lib/test.so.1',
                    '-DVALUE=two words', '', 'input with spaces.cc']
            result = self.capture(template, args)
            self.assertEqual(result[-len(args):], args)
            self.assertIn('-Wl,-rpath,/nix/store/a dir/lib', result)
            self.assertIn('-Wl,-rpath,/nix/store/tools/bin', result)
            self.assertIn('-Wl,-rpath,/nix/store/other/lib', result)
            self.assertLess(result.index('-B/nix/store/musl/lib/..'),
                            result.index('-B/nix/store/compiler/lib/gcc/target/10.4.0'))
            if template == 'wrappercxx.sh':
                self.assertLess(result.index('/nix/store/compiler/include/c++'),
                                result.index('-B/nix/store/musl/lib/..'))

    def test_libtool_version_special_case(self):
        for template in ['wrapper.sh', 'wrappercxx.sh']:
            self.assertEqual(self.capture(template, ['-v']), ['-v'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
