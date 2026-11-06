"""Reject summaries contradicted by retained upstream test records."""
import importlib
import json
from pathlib import Path
import tempfile
import unittest

inspect=importlib.import_module('source-gcc-graphviz-upstream').inspect


class Records(unittest.TestCase):
    def test_automake_records_and_unique_totals(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);(root/'flex.check.status').write_text('0')
            log='# TOTAL: 1\n# PASS: 1\n# SKIP: 0\n# XFAIL: 0\n# FAIL: 0\n# XPASS: 0\n# ERROR: 0\n'
            (root/'flex.check.log').write_text(log);trs=root/'case.trs';trs.write_text(':test-result: PASS\n')
            self.assertEqual(inspect('flex',root)['cases']['pass'],1)
            for bad in [log+'# PASS: 1\n',log.replace('# TOTAL: 1','# TOTAL: 2')]:
                (root/'flex.check.log').write_text(bad)
                with self.subTest(log=bad),self.assertRaises(AssertionError):inspect('flex',root)
            (root/'flex.check.log').write_text(log)
            for bad in [':test-result: FAIL\n','',':test-result: PASS\n:test-result: PASS\n']:
                trs.write_text(bad)
                with self.subTest(trs=bad),self.assertRaises(AssertionError):inspect('flex',root)
            trs.unlink()
            with self.assertRaises(AssertionError):inspect('flex',root)

    def test_meson_records_and_unique_summary(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);(root/'fontconfig.check.status').write_text('0');(root/'meson-logs').mkdir()
            log='Ok: 15\nFail: 0\n';(root/'fontconfig.check.log').write_text(log)
            records=[dict(name='case'+str(i),result='OK',returncode=0) for i in range(15)]
            path=root/'meson-logs/testlog.json'
            def save(rows):path.write_text(''.join(json.dumps(row)+'\n' for row in rows))
            save(records);self.assertEqual(inspect('fontconfig',root)['cases']['passed'],15)
            for rows in [records[:-1],records[:-1]+[records[0]],records[:-1]+[dict(name='case14',result='FAIL',returncode=1)]]:
                save(rows)
                with self.subTest(rows=rows[-1]),self.assertRaises(AssertionError):inspect('fontconfig',root)
            save(records);(root/'fontconfig.check.log').write_text(log+'Ok: 15\n')
            with self.assertRaises(AssertionError):inspect('fontconfig',root)


if __name__=='__main__':unittest.main()
