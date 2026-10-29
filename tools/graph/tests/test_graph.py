import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(sys.argv.pop(1))
spec = importlib.util.spec_from_file_location("compare", SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class GraphContract(unittest.TestCase):
    def setUp(self):
        self.before = {"packages.example_1": {"drv": "/nix/store/old.drv", "out": "/nix/store/output"}}

    def run_cli(self, after, *arguments, schema=1):
        with tempfile.TemporaryDirectory() as directory:
            before_path, after_path = Path(directory)/"before.json", Path(directory)/"after.json"
            before_path.write_text(json.dumps({"schema": 1, "entries": self.before}))
            after_path.write_text(json.dumps({"schema": schema, "entries": after}))
            return subprocess.run([sys.executable, str(SCRIPT), str(before_path), str(after_path), "--json", *arguments], capture_output=True, text=True)

    def test_new_versions_do_not_redefine_existing_versions(self):
        after = self.before | {"packages.example_2": {"drv": "/nix/store/new.drv", "out": "/nix/store/new"}}
        result = self.run_cli(after)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["added"], ["packages.example_2"])

    def test_changed_producer_requires_exact_reviewed_allowance(self):
        after = {"packages.example_1": {"drv": "/nix/store/new.drv", "out": "/nix/store/new"}}
        self.assertEqual(self.run_cli(after).returncode, 1)
        self.assertEqual(self.run_cli(after, "--allow-change", "packages.example_1").returncode, 0)
        self.assertEqual(self.run_cli(after, "--allow-change", "packages.*").returncode, 1)

    def test_removed_versions_and_stale_allowances_fail(self):
        self.assertEqual(self.run_cli({}).returncode, 1)
        self.assertEqual(self.run_cli(self.before, "--allow-change", "packages.typo").returncode, 1)

    def test_transport_change_can_be_compared_by_output(self):
        after = {"packages.example_1": {"drv": "/nix/store/new-source.drv", "out": "/nix/store/output"}}
        self.assertEqual(self.run_cli(after).returncode, 1)
        self.assertEqual(self.run_cli(after, "--out").returncode, 0)

    def test_alias_identity_is_part_of_graph(self):
        before = {"bases.default": dict(self.before["packages.example_1"], canonical="base1")}
        after = {"bases.default": dict(before["bases.default"], canonical="base2")}
        self.assertEqual(module.compare(before, after)["unexpectedChanges"], ["bases.default"])

    def test_invalid_snapshots_are_not_empty_successes(self):
        self.assertEqual(self.run_cli(self.before, schema=2).returncode, 2)
        self.assertEqual(self.run_cli({"packages.example_1": {"out": "missing drv"}}).returncode, 2)

    def test_report_only_preserves_changes_and_removals_without_rejecting_them(self):
        changed = {"packages.example_1": {"drv": "/nix/store/new.drv", "out": "/nix/store/new"}}
        result = self.run_cli(changed, "--report-only")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["changed"]["packages.example_1"],
                         {"before": self.before["packages.example_1"], "after": changed["packages.example_1"]})
        removed = self.run_cli({}, "--report-only")
        self.assertEqual(removed.returncode, 0, removed.stderr)
        self.assertEqual(json.loads(removed.stdout)["removed"], ["packages.example_1"])

    def test_report_only_still_rejects_malformed_graphs(self):
        self.assertEqual(self.run_cli(self.before, "--report-only", schema=2).returncode, 2)


if __name__ == "__main__":
    unittest.main()
