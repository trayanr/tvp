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
