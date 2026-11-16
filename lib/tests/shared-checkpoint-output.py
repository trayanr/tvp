"""Tiny filesystem controls for shared checkpoint and final-output operations."""
import importlib.util
import json
import os
from pathlib import Path
import runpy
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

LIB = Path(__file__).resolve().parent.parent


def module(name, path):
    specification = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(result)
    return result


class CheckpointControls(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="nix-build-checkpoint-control-")
        self.root = Path(self.temporary.name)
        self.original = self.root / "original"
        self.original.mkdir()
        (self.original / "source-date-epoch").write_text("315532800\n")
        self.source = self.original / "source"
        self.source.mkdir()
        (self.source / "compiled").write_text("compiled library")
        (self.source / "alias").symlink_to("compiled")
        self.stamp = 1234567890000000000
        os.utime(self.source / "compiled", ns=(self.stamp, self.stamp))
        self.checkpoint = self.root / "checkpoint"
        module("save_checkpoint", LIB / "build-checkpoint.py").save(
            self.original, self.checkpoint
        )
        shutil.rmtree(self.source)
        self.workspace = self.root / "workspace"
        self.workspace.mkdir()
        self.restore = module("restore_checkpoint", LIB / "restore-checkpoint.py").restore

    def tearDown(self):
        self.temporary.cleanup()

    def layout(self, **changes):
        path = self.checkpoint / "layout.json"
        value = json.loads(path.read_text())
        value.update(changes)
        path.write_text(json.dumps(value))

    def test_roundtrip_preserves_compiled_tree_links_and_timestamps(self):
        (self.checkpoint / "source" / "compiled").chmod(0o444)
        self.restore(self.checkpoint, self.workspace)
        self.assertEqual((self.source / "compiled").read_text(), "compiled library")
        self.assertEqual((self.source / "compiled").stat().st_mtime_ns, self.stamp)
        self.assertTrue((self.source / "compiled").stat().st_mode & stat.S_IWUSR)
        self.assertEqual(os.readlink(self.source / "alias"), "compiled")
        self.assertEqual((self.workspace / "tree-path").read_text(), str(self.source) + "\n")
        self.assertEqual((self.workspace / "source-date-epoch").read_text(), "315532800\n")

    def test_existing_destination_is_rejected(self):
        self.source.mkdir()
        with self.assertRaisesRegex(ValueError, "already exists"):
            self.restore(self.checkpoint, self.workspace)
        self.assertEqual(list(self.source.iterdir()), [])

    def test_noncanonical_and_unapproved_workspaces_are_rejected(self):
        for value in [str(self.original) + "/..", "/etc/tvp-checkpoint-control"]:
            with self.subTest(workspace=value):
                self.layout(workspace=value)
                with self.assertRaises(ValueError):
                    self.restore(self.checkpoint, self.workspace)
        self.assertFalse(self.source.exists())

    def test_symlinked_workspace_is_rejected_before_writes(self):
        shutil.rmtree(self.original)
        outside = self.root / "outside"
        outside.mkdir()
        self.original.symlink_to(outside, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "resolves outside"):
            self.restore(self.checkpoint, self.workspace)
        self.assertEqual(list(outside.iterdir()), [])

    def test_checkpoint_special_file_is_rejected(self):
        os.mkfifo(self.checkpoint / "source" / "fifo")
        with self.assertRaisesRegex(ValueError, "unsupported build-tree object"):
            self.restore(self.checkpoint, self.workspace)
        self.assertFalse(self.source.exists())


class LookupControls(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="tvp-lookup-control-")
        self.root = Path(self.temporary.name)
        (self.root / "bin").mkdir()
        (self.root / "lib").mkdir()
        (self.root / "lib" / "loader").write_text("loader")

    def tearDown(self):
        self.temporary.cleanup()

    def audit(self, script):
        arguments = [str(script), str(self.root), json.dumps({"paths": [], "elfKinds": None}),
                     str(LIB / "native-output")]
        with patch.object(sys, "argv", arguments), patch.dict(os.environ, {
            "NIX_BUILD_TOP": "/tmp/tvp-forbidden-build",
            "TMPDIR": "/tmp/tvp-forbidden-step",
            "TVP_ARTIFACT_ROOT": "/tmp/tvp-forbidden-artifact",
        }), patch.object(sys, "path", [str(LIB / "native-output")] + sys.path):
            return runpy.run_path(str(script))["audit"]

    def test_loader_policy_preserves_supported_tokens(self):
        audit = self.audit(LIB / "check-loader-paths.py")
        for value in ["$ORIGIN/../lib", "${ORIGIN}/../lib", "$ORIGIN/$LIB", "$PLATFORM/lib"]:
            with self.subTest(value=value):
                audit(value, self.root / "bin" / "program", rpath=True)

    def test_loader_policy_rejects_invalid_and_forbidden_lookup_paths(self):
        audit = self.audit(LIB / "check-loader-paths.py")
        for value in ["$UNKNOWN/lib", "/tmp/tvp-forbidden-build/lib",
                      "/tmp/tvp-forbidden-step/lib", "/tmp/tvp-forbidden-artifact/lib",
                      str(self.root / "missing"), "bad\0path", "bad\npath"]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                audit(value, self.root / "bin" / "program", rpath=True)

    def test_interpreter_policy_remains_absolute(self):
        audit = self.audit(LIB / "check-loader-paths.py")
        audit(str(self.root / "lib" / "loader"), self.root / "bin" / "program")
        with self.assertRaises(ValueError):
            audit("$ORIGIN/../lib/loader", self.root / "bin" / "program")

    def test_existing_strict_policy_does_not_accept_loader_tokens(self):
        audit = self.audit(LIB / "native-output" / "check-paths.py")
        audit(str(self.root / "lib"), self.root / "bin" / "program")
        with self.assertRaises(ValueError):
            audit("$ORIGIN/../lib", self.root / "bin" / "program")


class RelocationControls(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="tvp-relocate-control-")
        self.root = Path(self.temporary.name) / "final"
        self.root.mkdir()
        self.old = b"/artifact-" + b"x" * 180

    def tearDown(self):
        self.temporary.cleanup()

    def relocate(self):
        return subprocess.run([sys.executable, "-B", str(LIB / "relocate.py"),
                               str(self.root), os.fsdecode(self.old), "/unused-patchelf"],
                              capture_output=True, text=True)

    def test_text_and_binary_slots_and_internal_hardlinks(self):
        (self.root / "text").write_bytes(self.old + b"/share\n")
        (self.root / "binary").write_bytes(b"binary\0" + self.old + b"/lib\0")
        os.link(self.root / "text", self.root / "alias")
        result = self.relocate()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / "text").read_bytes(), os.fsencode(self.root) + b"/share\n")
        self.assertEqual((self.root / "alias").read_bytes(), (self.root / "text").read_bytes())
        self.assertEqual((self.root / "text").stat().st_nlink, 1)
        self.assertEqual((self.root / "alias").stat().st_nlink, 1)
        self.assertEqual((self.root / "binary").read_bytes(), b"binary\0" + os.fsencode(self.root)
                         + b"/" * (len(self.old) - len(os.fsencode(self.root))) + b"/lib\0")

    def test_external_hardlink_is_rejected_before_text_mutation(self):
        original = self.old + b"/bin\n"
        (self.root / "text").write_bytes(original)
        os.link(self.root / "text", self.root.parent / "outside")
        self.assertNotEqual(self.relocate().returncode, 0)
        self.assertEqual((self.root / "text").read_bytes(), original)

    def test_escaping_symlink_is_rejected_before_text_mutation(self):
        original = self.old + b"/bin\n"
        (self.root / "text").write_bytes(original)
        outside = self.root.parent / "outside"
        outside.write_text("outside")
        (self.root / "escape").symlink_to(outside)
        self.assertNotEqual(self.relocate().returncode, 0)
        self.assertEqual((self.root / "text").read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
