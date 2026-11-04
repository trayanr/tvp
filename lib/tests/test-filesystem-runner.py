"""Exercise skip boundaries and unchanged upstream exit/argument propagation."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

RUNNER = Path(sys.argv.pop(1)).resolve()


class Tests(unittest.TestCase):
    def invoke(self, suite, case, status, upstream_status=0):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            probe = root / "probe"
            upstream = root / "upstream"
            probe.write_text(
                f"#!{sys.executable}\nimport sys\n"
                "print('PROBE '+sys.argv[1])\n"
                f"raise SystemExit({status})\n"
            )
            upstream.write_text(
                f"#!{sys.executable}\nimport sys,json\n"
                "print('UPSTREAM '+json.dumps(sys.argv[1:]))\n"
                f"raise SystemExit({upstream_status})\n"
            )
            probe.chmod(0o755)
            upstream.chmod(0o755)
            return subprocess.run(
                [sys.executable, str(RUNNER), suite, str(probe), str(upstream), "--flag", case],
                cwd=root, text=True, capture_output=True,
            )

    def test_unsupported_cases_skip_without_running_upstream(self):
        for suite, case, capability in [
            ("attr", "attr.run", "xattrs"), ("attr", "restore.run", "xattrs"),
            ("acl", "cp.run", "acls"), ("acl", "misc.run", "acls"),
            ("acl", "setfacl-X.run", "acls"), ("acl", "sbits-restore.run", "set-id"),
        ]:
            with self.subTest(suite=suite, case=case):
                result = self.invoke(suite, "test/" + case, 77)
                self.assertEqual(result.returncode, 77)
                self.assertEqual(result.stdout.strip(), "PROBE " + capability)

    def test_upstream_failure_and_arguments_are_preserved_on_supported_filesystem(self):
        result = self.invoke("attr", "test/attr.run", 0, upstream_status=9)
        self.assertEqual(result.returncode, 9)
        self.assertIn('UPSTREAM ' + json.dumps(["--flag", "test/attr.run"]), result.stdout)

    def test_unexpected_probe_error_is_failure(self):
        result = self.invoke("acl", "test/misc.run", 3)
        self.assertEqual(result.returncode, 3)
        self.assertNotIn("UPSTREAM", result.stdout)

    def test_unmapped_cases_keep_original_runner(self):
        for suite, case in [("attr", "test/root/getfattr.run"), ("acl", "test/nfs/nfsacl.run"),
                            ("acl", "test/parse.test"), ("acl", "test/root/cp.run")]:
            with self.subTest(suite=suite, case=case):
                result = self.invoke(suite, case, 77, upstream_status=8)
                self.assertEqual(result.returncode, 8)
                self.assertNotIn("PROBE", result.stdout)
                self.assertIn("UPSTREAM", result.stdout)


if __name__ == "__main__":
    unittest.main()
