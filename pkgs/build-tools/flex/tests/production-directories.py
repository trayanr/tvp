"""The production selection changes only the top-level generated Makefile."""
import importlib.util
import os
from pathlib import Path
import sys
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("flex_production", sys.argv[1])
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class ProductionDirectories(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.makefile = self.root / "Makefile"

    def tearDown(self):
        self.temporary.cleanup()

    def test_old_and_new_source_layouts_preserve_other_rules(self):
        for extra in [[], ["lib"]]:
            directories = extra + ["src", "doc", "examples", "po", "tests", "tools"]
            source = "SUBDIRS = \\\n\t" + " \\\n\t".join(directories) + "\n\ncheck-local:\n\t@echo tests\n"
            self.makefile.write_text(source)
            helper.prepare(self.makefile)
            self.assertEqual(self.makefile.read_text(), "SUBDIRS = " + " ".join(d for d in directories if d != "tests") + "\n\ncheck-local:\n\t@echo tests\n")
            self.assertFalse((self.root / "Makefile.tvp-production").exists())

    def test_one_line_assignment(self):
        self.makefile.write_text("SUBDIRS = src tests doc\n")
        helper.prepare(self.makefile)
        self.assertEqual(self.makefile.read_text(), "SUBDIRS = src doc\n")

    def test_unexpected_layout_rejects_without_writes(self):
        for text in ["SUBDIRS = src\n", "SUBDIRS = tests\n", "SUBDIRS = src tests tests\n", "SUBDIRS = $(OTHER) tests\n", "SUBDIRS = src tests\nSUBDIRS = doc\n", "SUBDIRS = src tests\0\n"]:
            with self.subTest(text=text):
                self.makefile.write_text(text)
                with self.assertRaises(ValueError):
                    helper.prepare(self.makefile)
                self.assertEqual(self.makefile.read_text(), text)

    def test_aliases_reject_without_modifying_target(self):
        target = self.root / "target"
        target.write_text("SUBDIRS = src tests\n")
        self.makefile.symlink_to(target)
        with self.assertRaises(ValueError): helper.prepare(self.makefile)
        self.makefile.unlink()
        os.link(target, self.makefile)
        with self.assertRaises(ValueError): helper.prepare(self.makefile)
        self.assertEqual(target.read_text(), "SUBDIRS = src tests\n")

    def test_temporary_alias_rejects_before_any_write(self):
        self.makefile.write_text("SUBDIRS = src tests\n")
        target = self.root / "target"
        target.write_text("untouched")
        (self.root / "Makefile.tvp-production").symlink_to(target)
        with self.assertRaises(FileExistsError): helper.prepare(self.makefile)
        self.assertEqual(target.read_text(), "untouched")
        self.assertEqual(self.makefile.read_text(), "SUBDIRS = src tests\n")


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0]])
