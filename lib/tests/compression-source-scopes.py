"""Bounded controls for shared production/test preparation; no package compilation."""
import os
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile
import unittest

production, upstream, common = (Path(p).resolve(strict=True) for p in sys.argv[1:4])
source_files = runpy.run_path(str(common))["source_files"]


class ScopeTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name).resolve()
        (self.root / "build-aux").mkdir()
        (self.root / "tests").mkdir()
        (self.root / "src/scripts").mkdir(parents=True)
        (self.root / "configure").write_bytes(b"#!/bin/sh\necho configure\n")
        (self.root / "build-aux/ltmain.sh").write_bytes(
            b"#!/bin/sh\neval sys_lib_search_path=unchosen\n")
        (self.root / "tests/example.sh").write_bytes(b"#!/bin/sh\necho test\n")
        for name in ["xzdiff", "xzgrep", "xzmore", "xzless"]:
            (self.root / "src/scripts" / (name + ".in")).write_bytes(
                b"#!@POSIX_SHELL@\necho installed\n")

    def tearDown(self):
        self.temporary.cleanup()

    def snapshot(self):
        return {str(p.relative_to(self.root)): p.read_bytes()
                for p in self.root.rglob("*") if p.is_file() and not p.is_symlink()}

    def invoke(self, helper, family="xz", success=True):
        result = subprocess.run([sys.executable, "-B", str(helper), family,
                                 "/selected/bin/bash", str(common)],
                                cwd=self.root, capture_output=True, text=True,
                                env={**os.environ, "NIX_LDFLAGS": "-L/selected/lib"})
        self.assertEqual(result.returncode == 0, success, result.stderr)
        return result

    def test_production_does_not_interpret_or_rewrite_test_scripts(self):
        script = self.root / "tests/example.sh"
        script.write_bytes(b"#!/unsupported/test-policy\n\0\xff")
        before = script.read_bytes()
        self.invoke(production)
        self.assertEqual(script.read_bytes(), before)
        self.assertTrue((self.root / "configure").read_bytes().startswith(
            b"#!/selected/bin/bash\n"))
        self.assertIn(b"'/selected/lib'", (self.root / "build-aux/ltmain.sh").read_bytes())

    def test_test_driver_policy_stays_upstream(self):
        runner = self.root / "build-aux/test-driver"
        runner.write_bytes(b"#!/bin/sh\n# upstream-only \xff\n")
        before = runner.read_bytes()
        self.invoke(production)
        self.assertEqual(runner.read_bytes(), before)
        self.invoke(upstream, success=False)
        self.assertEqual(runner.read_bytes(), before)

    def test_upstream_binds_build_aux_test_driver(self):
        runner = self.root / "build-aux/test-driver"
        runner.write_bytes(b"#!/bin/sh\necho runner\n")
        self.invoke(upstream)
        self.assertTrue(runner.read_bytes().startswith(b"#!/selected/bin/bash\n"))

    def test_upstream_does_not_interpret_or_rewrite_production_text(self):
        configure = self.root / "configure"
        configure.write_bytes(b"unqualified production input\0\xff")
        before = configure.read_bytes()
        self.invoke(upstream)
        self.assertEqual(configure.read_bytes(), before)
        self.assertTrue((self.root / "tests/example.sh").read_bytes().startswith(
            b"#!/selected/bin/bash\n"))

    def test_configure_selected_test_frontend_is_preserved(self):
        script = self.root / "tests/generated.sh"
        script.write_bytes(b"#!/selected/bin/bash\necho generated\n")
        before = script.read_bytes()
        self.invoke(upstream)
        self.assertEqual(script.read_bytes(), before)

    def test_late_production_validation_precedes_every_write(self):
        (self.root / "build-aux/ltmain.sh").write_bytes(b"#!/bin/sh\nmissing anchor\n")
        before = self.snapshot()
        self.invoke(production, success=False)
        self.assertEqual(self.snapshot(), before)

    def test_late_upstream_validation_precedes_every_write(self):
        (self.root / "tests/zz-invalid.sh").write_bytes(b"#!/unsupported/interpreter\n")
        before = self.snapshot()
        self.invoke(upstream, success=False)
        self.assertEqual(self.snapshot(), before)

    def test_preexisting_temporary_precedes_every_write(self):
        (self.root / "configure.tvp-prepare").write_bytes(b"occupied")
        before = self.snapshot()
        self.invoke(production, success=False)
        self.assertEqual(self.snapshot(), before)

    def test_aliased_leaf_precedes_every_write(self):
        os.link(self.root / "configure", self.root / "alias")
        before = self.snapshot()
        self.invoke(production, success=False)
        self.assertEqual(self.snapshot(), before)

    def test_directory_alias_rejected(self):
        (self.root / "alias").symlink_to("tests")
        with self.assertRaises(ValueError):
            source_files(self.root)

    def test_special_file_rejected(self):
        os.mkfifo(self.root / "fifo")
        with self.assertRaises(ValueError):
            source_files(self.root)

    def test_bzip2_production_is_validation_only(self):
        for name in ["Makefile", "Makefile-libbz2_so", "bzlib.h"]:
            (self.root / name).write_bytes(b"preserved\n")
        before = self.snapshot()
        self.invoke(production, family="bzip2")
        self.assertEqual(self.snapshot(), before)


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0]])
