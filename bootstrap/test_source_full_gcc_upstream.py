"""Incomplete or contradictory DejaGNU evidence must fail closed."""
import importlib
import json
from pathlib import Path
import tempfile
import unittest
inspect=importlib.import_module('source-full-gcc-upstream').inspect

class Completion(unittest.TestCase):
    def evidence(self,root):
        suites={}
        for tool in ['gcc','g++','libstdc++','libgomp','libatomic','libitm']:
            name=tool+'.sum'
            (root/name).write_text('PASS: native coverage\n\t\t=== '+tool+' Summary ===\n# of expected passes\t1\n')
            suites[name]=dict(counts={'PASS':1},unexpected=[])
        (root/'upstream.json').write_text(json.dumps(dict(suites=suites)))

    def test_completed_coverage(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);self.evidence(root)
            self.assertEqual(inspect(root)['counts'],{'PASS':6})

    def test_missing_footer_and_incomplete_runs(self):
        for text in ['PASS: native coverage\n', '', 'PASS: native coverage\n=== gcc Summary ===\n# of expected passes\t1\nPASS: late\n']:
            with self.subTest(text=text),tempfile.TemporaryDirectory() as d:
                root=Path(d);self.evidence(root);(root/'gcc.sum').write_text(text)
                with self.assertRaises(AssertionError):inspect(root)

    def test_json_cannot_erase_raw_failure(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);self.evidence(root)
            p=root/'gcc.sum';p.write_text(p.read_text().replace('PASS: native coverage','FAIL: native coverage'))
            with self.assertRaises(AssertionError):inspect(root)

    def test_misclassified_footer(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);self.evidence(root)
            p=root/'gcc.sum';p.write_text(p.read_text().replace('expected passes','unsupported tests'))
            with self.assertRaises(AssertionError):inspect(root)

if __name__=='__main__':unittest.main()
