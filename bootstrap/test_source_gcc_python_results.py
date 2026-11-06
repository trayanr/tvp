"""Rejection controls for partial/contradictory pytest observations."""
import importlib
from pathlib import Path
import tempfile
import unittest

inspect=importlib.import_module('source-gcc-python-results').inspect


class Completion(unittest.TestCase):
    def test_completion_exit_records_and_footer_must_agree(self):
        xml='<testsuite tests="2" failures="0" errors="0" skipped="1"><testcase/><testcase><skipped/></testcase></testsuite>'
        log='=== 1 passed, 1 skipped in 0.1s ===\n'
        with tempfile.TemporaryDirectory() as directory:
            report=Path(directory)/'results.xml';report.write_text(xml)
            self.assertEqual(inspect(log,report,0)['passed'],1)
            for bad in ['',log.replace('===',''),log.replace('1 passed','2 passed'),log+'crash\n']:
                with self.subTest(log=bad),self.assertRaises(AssertionError):inspect(bad,report,0)
            with self.assertRaises(AssertionError):inspect(log,report,1)
            for bad in [xml.replace('tests="2"','tests="3"'),xml.replace('<skipped/>','')]:
                report.write_text(bad)
                with self.assertRaises(AssertionError):inspect(log,report,0)


if __name__=='__main__':
    unittest.main()
