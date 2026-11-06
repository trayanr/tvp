"""Negative controls for the newly introduced runtime mapping boundary."""
import importlib
import unittest
import tempfile
from pathlib import Path

observer=importlib.import_module('source-full-gcc-prerequisite-runtime-audit')


class Boundary(unittest.TestCase):
    def test_no_observation_is_not_evidence(self):
        with self.assertRaises(ValueError): observer.require_paths([],set())

    def test_development_reference_does_not_grant_execution(self):
        with tempfile.TemporaryDirectory() as directory:
            native=Path(directory)/'native'; old=Path(directory)/'construction'
            native.mkdir(); old.mkdir()
            (native/'libc.so.6').write_bytes(b'owned')
            (old/'libc.so.6').write_bytes(b'old')
            observer.require_paths([str(native/'libc.so.6')], {str(native)})
            with self.assertRaises(ValueError):
                observer.require_paths([str(native/'libc.so.6'),str(old/'libc.so.6')], {str(native)})
            (native/'escape.so').symlink_to(old/'libc.so.6')
            with self.assertRaises(ValueError):
                observer.require_paths([str(native/'escape.so')], {str(native)})



class UpstreamCompletion(unittest.TestCase):
    def test_crash_with_no_methods_is_not_success(self):
        inspect=importlib.import_module('source-full-gcc-prerequisite-upstream').inspect
        with tempfile.TemporaryDirectory() as d:
            root=Path(d); (root/'raw').mkdir()
            (root/'isl.check.log').write_text('segmentation fault\n')
            (root/'isl.check.status').write_text('139\n')
            with self.assertRaises(AssertionError): inspect('isl',root)
            (root/'isl.check.status').write_text('0\n')
            with self.assertRaises(AssertionError): inspect('isl',root)


if __name__=='__main__': unittest.main()
