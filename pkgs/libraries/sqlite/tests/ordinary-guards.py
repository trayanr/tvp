"""Tiny mutation/classification regressions; never build a SQLite producer."""
import importlib.util
import os
from pathlib import Path
import tempfile
import shutil
import subprocess
import sys
import unittest

HERE = Path(__file__).resolve().parents[1] / 'ordinary'


def module(name):
    spec = importlib.util.spec_from_file_location(name, HERE / (name + '.py'))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


finalize = module('finalize').finalize
namespace = module('prepare').namespace
classify = module('classify').classify
SQLITE_INSPECTOR = sys.argv.pop(1) if len(sys.argv) > 1 and sys.argv[1].startswith('/') else None


class Guards(unittest.TestCase):
    @unittest.skipUnless(SQLITE_INSPECTOR, 'Modern replay needs an explicit cached SQLite CLI')
    def test_complete_modern_runner_replay(self):
        cases = ['complete', 'missing-log', 'missing-db', 'invalid-db', 'native-error',
                 'duplicate-native', 'wrong-total', 'unfinished', 'NULL-count',
                 'job-output-mismatch', 'truncated-log', 'extra-log-job', 'missing-summary']
        for case in cases:
            with self.subTest(case=case), tempfile.TemporaryDirectory() as d:
                root = Path(d)
                (root/'exit').write_text('0\n')
                native = '0 errors out of 42 tests in 0.02 seconds Linux\n'
                wrapper = 'upstream veryquick jobs=2 cases=42 errors=0 unfinished=0\n'
                (root/'output').write_text(native + wrapper)
                rows = [(1, 'a.test', 'done', 20, 0, '0 errors out of 20 tests\n'),
                        (2, 'b.test', 'done', 22, 0, '0 errors out of 22 tests\n')]
                def sql(value):
                    return str(value) if isinstance(value, int) else "'" + value.replace("'", "''") + "'"
                statements = ['CREATE TABLE jobs(jobid INTEGER PRIMARY KEY, displayname TEXT, state TEXT, ntest INT, nerr INT, output TEXT);']
                statements += ['INSERT INTO jobs VALUES('+','.join(sql(value) for value in row)+');' for row in rows]
                log = ''.join(f'### {name} 1ms ({state})\n{body.strip()}\n'
                              for _, name, state, _, _, body in rows)
                (root/'runner.log').write_text(log)
                if case == 'native-error': (root/'output').write_text('1 errors out of 42 tests in 0.02 seconds Linux\n'+wrapper)
                elif case == 'duplicate-native': (root/'output').write_text(native+native+wrapper)
                elif case == 'wrong-total': (root/'output').write_text(native+wrapper.replace('cases=42', 'cases=40'))
                elif case == 'missing-summary': (root/'output').write_text(wrapper)
                elif case == 'unfinished': statements.append("UPDATE jobs SET state='running' WHERE jobid=1;")
                elif case == 'NULL-count': statements.append('UPDATE jobs SET ntest=NULL WHERE jobid=1;')
                elif case == 'job-output-mismatch': statements.append("UPDATE jobs SET output='0 errors out of 99 tests' WHERE jobid=1;")
                elif case == 'truncated-log': (root/'runner.log').write_text(log[:10])
                elif case == 'extra-log-job': (root/'runner.log').write_text(log+log)
                subprocess.run([SQLITE_INSPECTOR, '-batch', '-bail', '-init', '/dev/null',
                                str(root/'runner.db'), '\n'.join(statements)], check=True)
                if case == 'missing-log': (root/'runner.log').unlink()
                elif case == 'missing-db': (root/'runner.db').unlink()
                elif case == 'invalid-db': (root/'runner.db').write_bytes(b'invalid database')
                before = {p.name:p.read_bytes() for p in root.iterdir()}
                if case == 'complete': classify(root, SQLITE_INSPECTOR)
                else:
                    with self.assertRaises(ValueError): classify(root, SQLITE_INSPECTOR)
                self.assertEqual(before, {p.name:p.read_bytes() for p in root.iterdir()})

    def test_raw_cleanup_layout_rejects_before_mutation(self):
        for case in ['nested-directory', 'raw-symlink', 'surviving-alias']:
            with self.subTest(case=case), tempfile.TemporaryDirectory() as d:
                root, artifact = Path(d)/'out', Path(d)/'artifact'
                root.mkdir(); artifact.mkdir()
                pc = root/'sqlite3.pc'; original = f'prefix={artifact}\n'; pc.write_text(original)
                raw = root/'nix-support/sqlite-upstream';raw.mkdir(parents=True)
                (raw/'output').write_text('raw result')
                if case == 'nested-directory': (raw/'extra').mkdir()
                elif case == 'raw-symlink': (raw/'alias').symlink_to('output')
                else: (root/'alias').symlink_to('nix-support/sqlite-upstream/output')
                with self.assertRaises(ValueError): finalize(root, artifact)
                self.assertEqual(pc.read_text(), original)
                self.assertEqual((raw/'output').read_text(), 'raw result')

    def test_relocate_text_preserve_aliases_and_remove_raw(self):
        with tempfile.TemporaryDirectory() as d:
            root, artifact = Path(d) / 'out', Path(d) / 'artifact'
            root.mkdir(); artifact.mkdir()
            (root / 'lib').mkdir()
            pc = root / 'lib/sqlite3.pc'
            pc.write_text(f'prefix={artifact}\n')
            os.link(pc, root / 'lib/alias.pc')
            raw = root / 'nix-support/sqlite-upstream'
            raw.mkdir(parents=True)
            (raw / 'output').write_text(str(artifact))
            finalize(root, artifact)
            self.assertEqual(pc.read_text(), f'prefix={root}\n')
            self.assertEqual(pc.stat().st_ino, (root / 'lib/alias.pc').stat().st_ino)
            self.assertFalse(raw.exists())

    def test_preflight_before_any_write(self):
        for bad in ['outside-link', 'hardlink-role', 'NUL', 'encoding', 'fifo', 'external-hardlink']:
            with self.subTest(bad=bad), tempfile.TemporaryDirectory() as d:
                root, artifact = Path(d) / 'out', Path(d) / 'artifact'
                root.mkdir(); artifact.mkdir()
                pc = root / 'a.pc'; original = f'prefix={artifact}\n'; pc.write_text(original)
                if bad == 'outside-link': (root / 'bad').symlink_to(artifact)
                elif bad == 'hardlink-role': os.link(pc, root / 'payload')
                elif bad == 'external-hardlink': os.link(pc, Path(d) / 'outside.pc')
                elif bad == 'NUL': (root / 'z.pc').write_bytes(b'x\0y')
                elif bad == 'encoding': (root / 'z.pc').write_bytes(b'\xff')
                elif bad == 'fifo': os.mkfifo(root / 'bad')
                with self.assertRaises((ValueError, UnicodeError)): finalize(root, artifact)
                self.assertEqual(pc.read_text(), original)

    def test_root_and_source_link_guards(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d) / 'out'; root.mkdir()
            (root / 'a').write_text('a')
            os.link(root / 'a', root / 'b')
            with self.assertRaises(ValueError): namespace(root)
            link = Path(d) / 'link'; link.symlink_to(root)
            with self.assertRaises(ValueError): namespace(link)

    def test_raw_capture_keeps_nonpass(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d) / 'receipt'
            bash = shutil.which('bash')
            run = subprocess.run([bash, str(HERE / 'capture.sh'), str(root), bash,
                                  '-c', "printf 'unchanged raw nonpass\\n'; exit 7"],
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            self.assertEqual(run.returncode, 0)  # capture is never acceptance
            self.assertEqual((root / 'exit').read_bytes(), b'7\n')
            self.assertEqual((root / 'output').read_bytes(), b'unchanged raw nonpass\n')
            with self.assertRaises(ValueError): classify(root)

    def test_raw_acceptance_and_fail_closed(self):
        cases = [
            ('0 errors out of 42 tests\n', '0\n', True),
            ('upstream veryquick jobs=5 cases=42 errors=0 unfinished=0\n', '0\n', False),
            ('1 errors out of 42 tests\n', '0\n', False),
            ('0 errors out of 42 tests\n', '1\n', False),
            ('0 errors out of 42 tests\nSegmentation fault\n', '0\n', False),
            ('0 errors out of 42 tests\n0 errors out of 42 tests\n', '0\n', False),
            ('no result\n', '0\n', False),
            ('0 errors out of 42 tests\nunknown.test... Unexpected\n', '0\n', False),
            ('0 errors out of 42 tests\nnot ok extra record\n', '0\n', False),
            ('upstream veryquick jobs=5 cases=42 errors=0 unfinished=1\n', '0\n', False),
            ('1 errors out of 42 tests\nupstream veryquick jobs=5 cases=42 errors=0 unfinished=0\n', '0\n', False),
            ('0 errors out of 0 tests\n', '0\n', False),
        ]
        for output, status, accepted in cases:
            with self.subTest(output=output), tempfile.TemporaryDirectory() as d:
                root = Path(d); (root/'exit').write_text(status); (root/'output').write_text(output)
                before = (root/'output').read_bytes()
                if accepted: classify(root)
                else:
                    with self.assertRaises(ValueError): classify(root)
                self.assertEqual((root/'output').read_bytes(), before)


if __name__ == '__main__':
    unittest.main()
