"""Semantic rejection controls at the installed result parser boundary."""
import importlib
from pathlib import Path
import tempfile
import unittest

inspect = importlib.import_module('source-gcc-test-harness-results').inspect


class Completion(unittest.TestCase):
    def test_incomplete_empty_nonzero_and_disagreement(self):
        good = 'PASS: compile c\n\t=== tvp Summary ===\n# of expected passes\t1\nruntest completed at Fri Nov 6\n'
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for suffix in ['sum', 'log']:
                (root/('tvp.'+suffix)).write_text(good)
            self.assertEqual(inspect(root, 0)['counts'], {'PASS': 1})
            with self.assertRaises(AssertionError):
                inspect(root, 1)
            for bad in ['', good.replace('runtest completed at', 'crashed at'),
                        good.replace('PASS: compile c\n', ''),
                        good.replace('passes\t1', 'passes\t2'),
                        good.replace('PASS:', 'UNRESOLVED:')]:
                (root/'tvp.log').write_text(bad)
                with self.subTest(bad=bad), self.assertRaises(AssertionError):
                    inspect(root, 0)


class UpstreamCompletion(unittest.TestCase):
    def test_dejagnu_outcome_footers_and_outer_completion(self):
        upstream = importlib.import_module('source-gcc-test-harness-upstream')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root/'dejagnu.check.status').write_text('0\n')
            (root/'dejagnu.check.log').write_text('upstream self-tests\n')
            (root/'raw/build').mkdir(parents=True)
            for tool in ['launcher', 'libdejagnu', 'report-card', 'runtest']:
                records = ''.join('PASS: case '+str(n)+'\n' for n in range(130))
                records += 'XFAIL: known case\nUNSUPPORTED: unavailable target\nUNTESTED: manual case\n'
                summary = '\t=== '+tool+' Summary ===\n'
                summary += '# of expected passes\t130\n# of expected failures\t1\n'
                summary += '# of unsupported tests\t1\n# of untested testcases\t1\n'
                (root/'raw/build'/(tool+'.sum')).write_text(records+summary)
                # Nested child output is not part of the outer test records.
                log = 'FAIL: intentional child\nruntest completed at nested child\n'
                log += records+summary+'runtest completed at outer run\n'
                (root/'raw/build'/(tool+'.log')).write_text(log)
            self.assertEqual(upstream.inspect('dejagnu', root)['tools']['runtest']['counts']['PASS'], 130)
            path = root/'raw/build/runtest.log'
            good = path.read_text()
            for bad in [good.replace('runtest completed at outer run\n', ''),
                        good+'# of expected passes\t130\n',
                        good+'# of framework errors\t1\n'] + [
                            good.replace('# of '+label+'\t1', '# of '+label+'\t2')
                            for label in ['expected failures', 'unsupported tests', 'untested testcases']]:
                path.write_text(bad)
                with self.subTest(bad=bad[-250:]), self.assertRaises(AssertionError):
                    upstream.inspect('dejagnu', root)

    def test_zero_exit_without_a_real_suite_is_rejected(self):
        upstream = importlib.import_module('source-gcc-test-harness-upstream')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root/'expect.check.status').write_text('0\n')
            for text in ['', 'all.tcl: Total 0 Passed 0 Skipped 0 Failed 0\n',
                         'all.tcl: Total 1 Passed 0 Skipped 0 Failed 1\n']:
                (root/'expect.check.log').write_text(text)
                with self.subTest(text=text), self.assertRaises(AssertionError):
                    upstream.inspect('expect', root)
            (root/'expect.check.status').write_text('139\n')
            with self.assertRaises(AssertionError):
                upstream.inspect('expect', root)


if __name__ == '__main__':
    unittest.main()
