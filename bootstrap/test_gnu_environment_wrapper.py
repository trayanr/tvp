"""Opt-in argv contracts supplement the real source-build protocol fixtures."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

BASH = sys.argv.pop(1)
TEMPLATE = Path(sys.argv.pop(1)).read_text()


class ProtocolArgv(unittest.TestCase):
    def capture(self, args, *, program='gcc', flags=None, response=None):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            compiler = root / 'raw'
            compiler.mkdir()
            for name in ['gcc', 'g++', 'cpp']:
                p = compiler / name
                p.write_text('#!' + BASH + '\nprintf "%s\\0" "$@"\n')
                p.chmod(0o755)
            wrapper = root / program
            wrapper.write_text(TEMPLATE.replace('@bash@', BASH).replace('@tools@', '')
                               .replace('@compiler@', str(compiler)))
            if response is not None:
                (root / 'flags.rsp').write_text(response)
            env = dict(NIX_CFLAGS_COMPILE='-DCOMPILE=1', NIX_CFLAGS_LINK='-DLINK=1',
                       NIX_LDFLAGS='-rpath /literal/$HOME;*')
            env.update(flags or {})
            r = subprocess.run([BASH, str(wrapper), *args], cwd=root, env=env,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            return r.returncode, r.stdout.rstrip(b'\0').decode().split('\0')

    def test_compile_modes(self):
        for mode in ['-c', '--compile', '-S', '--assemble', '-E', '--preprocess',
                     '-M', '-MM', '-fsyntax-only']:
            with self.subTest(mode=mode):
                code, argv = self.capture([mode, 'source.c'])
                self.assertEqual(code, 0)
                self.assertEqual(argv, ['-DCOMPILE=1', mode, 'source.c'])

    def test_queries(self):
        for program in ['gcc', 'cpp', 'g++']:
            for mode in ['-v', '--version', '-dumpmachine', '-print-search-dirs',
                         '--print-search-dirs', '--target-help']:
                with self.subTest(program=program, mode=mode):
                    self.assertEqual(self.capture([mode], program=program), (0, [mode]))
        self.assertEqual(self.capture(['@flags.rsp'], response='-v'), (0, ['@flags.rsp']))

    def test_response_classification_and_forwarding(self):
        for response in ['-c input.c', '--compile input.c', '-\\\nc input.c',
                         '-c "input space,comma.c"', '-c input.c -o "open quote']:
            with self.subTest(response=response):
                self.assertEqual(self.capture(['@flags.rsp'], response=response),
                                 (0, ['-DCOMPILE=1', '@flags.rsp']))

    def test_link_order_literal_argv_and_linker_words(self):
        args = ['-v', '-x', 'c', '-', '-DNAME=space,comma value', '$(no-eval)', '']
        code, argv = self.capture(args)
        self.assertEqual(code, 0)
        self.assertEqual(argv, ['-DCOMPILE=1', '-DLINK=1', *args,
                                '-Xlinker', '-rpath', '-Xlinker', '/literal/$HOME;*'])

    def test_clear_unsupported_modes_and_encoding(self):
        for flags in [dict(NIX_HARDENING_ENABLE='fortify'), dict(NIX_LDFLAGS='a,b'),
                      dict(NIX_CFLAGS_LINK='-static-pie')]:
            with self.subTest(flags=flags):
                self.assertEqual(self.capture(['input.c'], flags=flags)[0], 64)
        self.assertEqual(self.capture(['@flags.rsp'], response='-m32 -c input.c')[0], 64)


if __name__ == '__main__':
    unittest.main(verbosity=2)
