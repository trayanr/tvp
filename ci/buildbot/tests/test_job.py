from contextlib import contextmanager
import json
import os
from pathlib import Path
from types import SimpleNamespace
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import job


@contextmanager
def directory():
    before = Path.cwd()
    with tempfile.TemporaryDirectory() as temporary:
        os.chdir(temporary)
        try:
            yield Path(temporary)
        finally:
            os.chdir(before)


class FrozenValidation(unittest.TestCase):
    def run_validation(self, phase, wait_code, base=""):
        commands = []
        def output(argv, **kwargs):
            commands.append(argv)
            if argv == ["nix", "--version"]:
                return "nix (Nix) 2.34.9\n"
            if argv[:1] == ["git"]:
                return "a" * 40 + "\n"
            if "--report-only" in argv:
                return json.dumps({"added": ["packages.new_1"],
                                   "changed": {"packages.consumer_1": {"before": {}, "after": {}}},
                                   "removed": ["packages.old_1"]})
            if "start" in argv:
                return json.dumps({"run": "/immutable/run-17", "runner": "/immutable/run-17/runner/bin/tvp-test"})
            if "status" in argv:
                return json.dumps({"phase": phase, "counts": {"passed": 1}, "reportedFailedDerivations": []})
            raise AssertionError(argv)
        def run(argv, **kwargs):
            commands.append(argv)
            return SimpleNamespace(returncode=wait_code)
        args = SimpleNamespace(repository="trayanr/tvp", head="a" * 40, base=base, tools_ref="github:trayanr/tvp/" + "b" * 40, compare="compare.py")
        with directory(), patch.object(job, "checkout"), patch.object(job, "execute", side_effect=run), \
             patch.object(job.subprocess, "check_output", side_effect=output), \
             patch.object(job.subprocess, "run", side_effect=run):
            result, code = job.validate(args)
            self.assertTrue(Path("evidence/status.json").exists())
            if base:
                self.graph_diff = json.loads(Path("evidence/graph-diff.json").read_text())
        return code, commands

    def test_wait_success_cannot_hide_failed_suite_results(self):
        code, commands = self.run_validation("failed", 0)
        self.assertEqual(code, 1)
        wait = next(c for c in commands if "wait" in c)
        self.assertEqual(wait[0], "/immutable/run-17/runner/bin/tvp-test")
        self.assertNotIn("latest", " ".join(wait))

    def test_runner_exit_failure_cannot_hide_behind_passed_status(self):
        self.assertEqual(self.run_validation("passed", 1)[0], 1)

    def test_only_both_success_signals_pass(self):
        self.assertEqual(self.run_validation("passed", 0)[0], 0)

    def test_master_records_producers_before_read_only_checks_with_full_traces(self):
        _, commands = self.run_validation("passed", 0)
        graph = next(c for c in commands if c[:2] == ['nix', 'eval'])
        check = next(c for c in commands if c[:3] == ['nix', 'flake', 'check'])
        self.assertTrue(graph[-1].endswith('/candidate#graph'))
        self.assertLess(commands.index(graph), commands.index(check))
        for command in commands:
            if command[:1] == ['nix'] and command[1] in ['eval', 'flake', 'run']:
                self.assertIn('--show-trace', command)

    def test_operator_stop_targets_the_exact_frozen_run(self):
        handlers = {}
        calls = []
        def register(sig, handler):
            handlers[sig] = handler
            return "previous"
        def run(argv, **kwargs):
            calls.append(argv)
            if "wait" in argv:
                handlers[job.signal.SIGTERM](None, None)
            return SimpleNamespace(returncode=1)
        with patch.object(job.signal, "signal", side_effect=register), patch.object(job.subprocess, "run", side_effect=run):
            job.wait_for_run("/frozen/runner", "/immutable/run-17")
        self.assertIn(["/frozen/runner", "stop", "--run", "/immutable/run-17"], calls)

    def test_changed_and_removed_producers_are_evidence_not_a_build_gate(self):
        code, commands = self.run_validation("passed", 0, base="c" * 40)
        self.assertEqual(code, 0)
        report = next(c for c in commands if "--report-only" in c)
        start = next(c for c in commands if "start" in c)
        self.assertLess(commands.index(report), commands.index(start))
        self.assertIn("packages.consumer_1", self.graph_diff["changed"])
        self.assertEqual(self.graph_diff["removed"], ["packages.old_1"])
        self.assertTrue(self.graph_diff["informational"])
        self.assertEqual(self.graph_diff["ciIdentity"]["base"], "c" * 40)

    def test_informational_graph_report_cannot_hide_failed_validation(self):
        self.assertEqual(self.run_validation("failed", 1, base="c" * 40)[0], 1)

    def test_checkout_rejects_mutable_refs_before_executing_git(self):
        with patch.object(job, "execute") as execute:
            with self.assertRaises(ValueError):
                job.checkout("trayanr/tvp", "master", Path("candidate"))
            execute.assert_not_called()


if __name__ == '__main__':
    unittest.main()
