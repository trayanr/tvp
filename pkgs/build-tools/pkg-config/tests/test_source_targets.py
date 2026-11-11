"""Focused containment controls for the source operation shared with Meson."""
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest


spec = importlib.util.spec_from_file_location(
    "source_targets", Path(__file__).resolve().parents[2] / "source-targets.py")
targets = importlib.util.module_from_spec(spec)
spec.loader.exec_module(targets)


class SourceTargetsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.directory = Path(self.tmp.name).resolve()
        self.root = self.directory / "source"
        self.root.mkdir()
        self.outside = self.directory / "outside"
        self.outside.mkdir()
        self.marker = self.outside / "target.c"
        self.marker.write_bytes(b"outside\n")
        self.marker.chmod(0o640)

    def reject(self, relative="sub/target.c", root=None):
        before = (self.marker.read_bytes(), self.marker.stat().st_mode)
        with self.assertRaises((ValueError, OSError, UnicodeError)):
            targets.text_file(relative, self.root if root is None else root)
        self.assertEqual((self.marker.read_bytes(), self.marker.stat().st_mode), before)

    def test_regular_text_preserves_contents(self):
        (self.root / "sub").mkdir()
        leaf = self.root / "sub/target.c"
        leaf.write_text("int answer = 42;\n")
        path, text = targets.text_file("sub/target.c", self.root)
        self.assertEqual(path, leaf)
        self.assertEqual(text, "int answer = 42;\n")
        self.assertEqual(leaf.read_text(), text)

    def test_linked_parent(self):
        (self.root / "sub").symlink_to(self.outside, target_is_directory=True)
        self.reject()

    def test_linked_leaf(self):
        (self.root / "sub").mkdir()
        (self.root / "sub/target.c").symlink_to(self.marker)
        self.reject()

    def test_hardlinked_leaf(self):
        (self.root / "sub").mkdir()
        os.link(self.marker, self.root / "sub/target.c")
        self.reject()

    def test_linked_root_or_ancestor(self):
        alias = self.directory / "alias"
        alias.symlink_to(self.root, target_is_directory=True)
        self.reject(root=alias)
        (self.root / "sub").mkdir()
        self.reject("target.c", root=alias / "sub")

    def test_missing_or_special_targets(self):
        (self.root / "sub").mkdir()
        self.reject()
        (self.root / "sub/target.c").mkdir()
        self.reject()
        (self.root / "sub/target.c").rmdir()
        os.mkfifo(self.root / "sub/target.c")
        self.reject()

    def test_invalid_relative_paths(self):
        for path in ("", "/outside/target.c", "../outside/target.c", "./sub/target.c",
                     "sub//target.c", "sub/../target.c", "sub/target.c/", "sub/\0target.c"):
            with self.subTest(path=path):
                self.reject(path)

    def test_invalid_text_is_not_modified(self):
        (self.root / "sub").mkdir()
        leaf = self.root / "sub/target.c"
        for data in (b"int answer;\0\n", b"\xff\n"):
            leaf.write_bytes(data)
            self.reject()
            self.assertEqual(leaf.read_bytes(), data)


if __name__ == "__main__":
    unittest.main()
