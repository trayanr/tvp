from contextlib import contextmanager
from io import StringIO
import json
import os
import subprocess
from pathlib import Path
from types import SimpleNamespace
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import job
from policy import result_properties


@contextmanager
def directory():
    before = Path.cwd()
    with tempfile.TemporaryDirectory() as temporary:
        os.chdir(temporary)
        try:
            yield Path(temporary)
        finally:
            os.chdir(before)


def write_snapshot(argv):
    Path(argv[argv.index("--out-link") + 1]).write_text(json.dumps({
        "schema": 1, "rev": "a" * 40, "graphJson": '{"schema":1,"entries":{}}', "plan": None,
    }))


class FrozenValidation(unittest.TestCase):
    def run_validation(self, phase, exit_code, base="", scope="smoke", full=False,
                       receipt_mode="normal", receipt_changes=None, catalogue=False):
        commands = []
        def output(argv, **kwargs):
            commands.append(argv)
            if argv == ["nix", "--version"]:
                return "nix (Nix) 2.34.9\n"
            if argv[:3] == ["nix", "eval", "--json"]:
                return "false\n"
            if argv[:1] == ["git"]:
                return base + "\n"
            if "--report-only" in argv:
                return json.dumps({"added": ["packages.new_1"],
                                   "changed": {"packages.consumer_1": {"before": {}, "after": {}}},
                                   "removed": ["packages.old_1"]})
            raise AssertionError(argv)
        def run(argv, **kwargs):
            commands.append(argv)
            if argv[:2] == ["nix", "build"] and "--expr" in argv:
                write_snapshot(argv)
            if argv[-1].endswith("#smokeTests.x86_64-linux.all"):
                Path(argv[argv.index("--out-link") + 1]).touch()
            if argv[:3] == ["nix", "flake", "check"]:
                kwargs["stdout"].write(b"flake evaluation output\n")
                self.assertEqual(kwargs["stderr"], subprocess.STDOUT)
            if "all" in argv:
                self.assertNotIn("--json", argv)
                self.assertIsNone(kwargs.get("stdout"))
                self.assertIsNone(kwargs.get("stderr"))
                self.assertEqual(kwargs["env"]["TVP_CI_PROGRESS"], "1")
                self.assertNotIn("TVP_CI_FROZEN_SMOKE_PLAN", kwargs["env"])
                validation = Path(argv[argv.index("--state-dir") + 1])
                run_path = validation / "runs/run-17"
                run_path.mkdir(parents=True)
                (validation / "latest").symlink_to(run_path)
                if catalogue:
                    (run_path / "plan.json").write_text(json.dumps({
                        "revision": "a" * 40, "system": "x86_64-linux", "validationScope": scope,
                    }))
                receipt = {
                    "run": str(run_path), "runner": str(run_path / "runner/bin/tvp-test"),
                    "phase": phase, "counts": {"passed": 1}, "reportedFailedDerivations": [],
                    "validationScope": scope, "full": full,
                }
                receipt.update(receipt_changes or {})
                if receipt_mode != "missing":
                    (run_path / "result.json").write_text(
                        "not valid json" if receipt_mode == "malformed" else json.dumps(receipt))
                return subprocess.CompletedProcess(argv, exit_code)
            return subprocess.CompletedProcess(argv, 0)
        args = SimpleNamespace(repository="trayanr/tvp", head="a" * 40, base=base, target_branch="master", tools_ref="github:trayanr/tvp/" + "b" * 40, compare="compare.py")
        args.catalogue = catalogue
        with directory(), patch.object(job, "checkout"), patch.object(job, "execute", side_effect=run), \
             patch.object(job.subprocess, "check_output", side_effect=output), \
             patch.object(job.subprocess, "run", side_effect=run):
            result, code = job.validate(args)
            self.assertTrue(Path("evidence/status.json").exists())
            if base:
                self.graph_diff = json.loads(Path("evidence/graph-diff.json").read_text())
                self.assertIn("added packages.new_1", Path("evidence/graph-diff.log").read_text())
            identity = json.loads(Path("evidence/identity.json").read_text())
            self.assertEqual(identity['merge'], args.head)
            self.assertFalse(any('merge' in c for c in commands))
            launch = json.loads(Path("evidence/launch.json").read_text())
            run_path = Path.cwd() / 'validation/runs/run-17'
            self.assertEqual(launch['run'], str(run_path))
            self.assertEqual(launch['runner'], str(run_path / 'runner/bin/tvp-test'))
        return code, commands

    def test_exit_success_cannot_hide_failed_suite_results(self):
        code, commands = self.run_validation("failed", 0)
        self.assertEqual(code, 1)
        command = next(c for c in commands if "all" in c)
        self.assertNotIn("latest", " ".join(command))
        self.assertFalse(any("wait" in c or "status" in c for c in commands))

    def test_runner_exit_failure_cannot_hide_behind_passed_status(self):
        self.assertEqual(self.run_validation("passed", 1)[0], 1)

    def test_only_both_success_signals_pass(self):
        code, commands = self.run_validation("passed", 0)
        self.assertEqual(code, 0)
        command = next(c for c in commands if "all" in c)
        self.assertIn("--smoke", command)
        self.assertNotIn("--full", command)
        self.assertEqual(command[3], 'github:trayanr/tvp/' + 'b' * 40 + '#test')

    def test_smoke_ci_rejects_a_full_scope_result(self):
        with self.assertRaisesRegex(ValueError, "requested smoke plan"):
            self.run_validation("passed", 0, scope="full", full=True)

    def test_catalogue_runs_direct_smoke_before_evaluating_catalogue(self):
        code, commands = self.run_validation("passed", 0, scope="catalogue", full=True, catalogue=True)
        self.assertEqual(code, 0)
        smoke = next(c for c in commands if c[-1].endswith("#smokeTests.x86_64-linux.all"))
        catalogue = next(c for c in commands if "--catalogue" in c)
        graph = next(c for c in commands if c[-1].endswith("#graph"))
        self.assertLess(commands.index(smoke), commands.index(graph))
        self.assertLess(commands.index(graph), commands.index(catalogue))
        self.assertFalse(any("--expr" in command for command in commands))

    def test_catalogue_rejects_a_smoke_scope_receipt(self):
        with self.assertRaisesRegex(ValueError, "requested catalogue plan"):
            self.run_validation("passed", 0, catalogue=True)

    def test_success_requires_the_current_run_receipt(self):
        for mode in ["missing", "malformed"]:
            with self.subTest(mode=mode), self.assertRaises((OSError, ValueError)):
                self.run_validation("passed", 0, receipt_mode=mode)

    def test_receipt_cannot_name_another_run(self):
        with self.assertRaises(ValueError):
            self.run_validation("passed", 0, receipt_changes={"run": "/foreign/run"})

    def test_latest_receipt_cannot_escape_the_validation_directory(self):
        with directory() as root:
            validation = root / "validation"
            validation.mkdir()
            foreign = root / "foreign-run"
            foreign.mkdir()
            (validation / "latest").symlink_to(foreign)
            (foreign / "result.json").write_text(json.dumps({"run": str(foreign)}))
            with self.assertRaises(ValueError):
                job.read_result(validation)

    def test_master_records_producers_before_read_only_checks_with_full_traces(self):
        _, commands = self.run_validation("passed", 0)
        snapshot = next(c for c in commands if c[:2] == ['nix', 'build'])
        check = next(c for c in commands if c[:3] == ['nix', 'flake', 'check'])
        self.assertIn('/candidate?rev=' + 'a' * 40, snapshot[-1])
        self.assertIn('smokeTestPlans', snapshot[-1])
        self.assertLess(commands.index(snapshot), commands.index(check))
        for command in commands:
            if command[:1] == ['nix'] and command[1] in ['build', 'eval', 'flake', 'run']:
                self.assertIn('--show-trace', command)

    def test_foreground_command_inherits_the_worker_owner_lock(self):
        _, commands = self.run_validation("passed", 0)
        command = next(c for c in commands if "all" in c)
        owner = command[command.index('--owner-lock') + 1]
        self.assertEqual(Path(owner).name, 'validation-owner.lock')

    def test_changed_and_removed_producers_are_evidence_not_a_build_gate(self):
        code, commands = self.run_validation("passed", 0, base="c" * 40)
        self.assertEqual(code, 0)
        report = next(c for c in commands if "--report-only" in c)
        command = next(c for c in commands if "all" in c)
        self.assertLess(commands.index(report), commands.index(command))
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

    def test_queued_pr_rejected_before_any_nix_for_outdated_or_divergent_target(self):
        for current, ancestry in [('d' * 40, 0), ('c' * 40, 1)]:
            args = SimpleNamespace(repository='trayanr/tvp', head='a' * 40, base='c' * 40,
                                   target_branch='release/next', compare='compare.py', tools_ref='unused')
            calls = []
            def output(argv, **kwargs):
                calls.append(argv)
                self.assertEqual(argv[0], 'git')
                return current + '\n'
            def run(argv, **kwargs):
                calls.append(argv)
                self.assertEqual(argv[0], 'git')
                return subprocess.CompletedProcess(argv, ancestry)
            with directory(), patch.object(job, 'checkout') as checkout, \
                 patch.object(job, 'execute', side_effect=lambda argv, **kwargs: calls.append(argv)), \
                 patch.object(job.subprocess, 'check_output', side_effect=output), \
                 patch.object(job.subprocess, 'run', side_effect=run):
                with self.assertRaises(ValueError):
                    job.validate(args)
                self.assertEqual(checkout.call_count, 1)
                self.assertFalse(Path('evidence/identity.json').exists())
            self.assertTrue(any('refs/heads/release/next' in c for c in calls))

    def test_ancestry_git_errors_fail_closed(self):
        with patch.object(job, 'execute'), \
             patch.object(job.subprocess, 'check_output', return_value='c' * 40 + '\n'), \
             patch.object(job.subprocess, 'run', return_value=subprocess.CompletedProcess([], 128)):
            with self.assertRaises(subprocess.CalledProcessError):
                job.require_current_target('trayanr/tvp', Path('candidate'), 'c' * 40, 'a' * 40, 'master')

    def test_unsafe_target_branches_are_rejected_without_fetching(self):
        for branch in ['', '--upload-pack=evil', 'master\nother', 'master\r']:
            with patch.object(job, 'execute') as execute:
                with self.assertRaises(ValueError):
                    job.require_current_target('trayanr/tvp', Path('candidate'), 'c' * 40, 'a' * 40, branch)
                execute.assert_not_called()
        for branch in ['@{-1}', 'a..b', 'a b', 'a:b', 'a.lock', '/master']:
            with self.assertRaises(subprocess.CalledProcessError), patch.object(job.subprocess, 'check_output') as output:
                job.require_current_target('trayanr/tvp', Path('candidate'), 'c' * 40, 'a' * 40, branch)
            output.assert_not_called()


class PreflightLogging(unittest.TestCase):
    output = b"".join(f"checking derivation {i}\n".encode() for i in range(4200))
    diagnostics = b"".join(f"trace detail {i}\n".encode() for i in range(60)) + b"error: invalid fixture\n"

    def execute_check(self, argv, **kwargs):
        self.assertEqual(argv[:3], ["nix", "flake", "check"])
        self.assertIn("--show-trace", argv)
        self.assertIn("--no-build", argv)
        self.assertEqual(kwargs["stderr"], subprocess.STDOUT)
        # Use real stdout/stderr file descriptors so the test catches accidental
        # console inheritance and lost diagnostics, rather than just kwargs.
        script = ("import sys; sys.stdout.buffer.write(" + repr(self.output) + "); "
                  "sys.stdout.flush(); sys.stderr.buffer.write(" + repr(self.diagnostics) + "); "
                  "sys.stderr.flush(); sys.exit(" + str(self.exit_code) + ")")
        return subprocess.run([sys.executable, "-c", script], check=True, **kwargs)

    def test_success_keeps_all_output_in_artifact_and_console_short(self):
        self.exit_code = 0
        with directory(), patch.object(job, "execute", side_effect=self.execute_check), \
             patch("sys.stdout", new_callable=StringIO) as stdout, \
             patch("sys.stderr", new_callable=StringIO) as stderr:
            Path("evidence").mkdir()
            job.check_flake(Path("candidate"), Path("evidence"))
            self.assertEqual(Path("evidence/flake-check.log").read_bytes(), self.output + self.diagnostics)
            self.assertEqual(len(stdout.getvalue().splitlines()), 2)
            self.assertIn("Flake evaluation passed", stdout.getvalue())
            self.assertNotIn("checking derivation", stdout.getvalue())
            self.assertEqual(stderr.getvalue(), "")

    def test_failure_keeps_full_log_and_prints_only_bounded_tail(self):
        self.exit_code = 23
        with directory(), patch.object(job, "execute", side_effect=self.execute_check), \
             patch("sys.stdout", new_callable=StringIO) as stdout, \
             patch("sys.stderr", new_callable=StringIO) as stderr:
            Path("evidence").mkdir()
            with self.assertRaises(subprocess.CalledProcessError) as failure:
                job.check_flake(Path("candidate"), Path("evidence"))
            self.assertEqual(failure.exception.returncode, 23)
            self.assertEqual(Path("evidence/flake-check.log").read_bytes(), self.output + self.diagnostics)
            self.assertNotIn("passed", stdout.getvalue())
            self.assertIn("error: invalid fixture", stderr.getvalue())
            self.assertIn("evidence/flake-check.log", stderr.getvalue())
            self.assertNotIn("checking derivation 0", stderr.getvalue())
            self.assertLessEqual(len(stderr.getvalue().splitlines()), 41)
            self.assertLess(len(stderr.getvalue().encode()), 16300)

    def test_preflight_failure_stops_before_catalogue_start(self):
        self.exit_code = 23
        commands = []
        def execute(argv, **kwargs):
            commands.append(argv)
            if argv[:3] == ["nix", "flake", "check"]:
                return self.execute_check(argv, **kwargs)
            write_snapshot(argv)
            return subprocess.CompletedProcess(argv, 0)
        args = SimpleNamespace(repository="trayanr/tvp", head="a" * 40, base="",
                               target_branch="master", tools_ref="pinned", compare="compare.py")
        with directory(), patch.object(job, "checkout"), patch.object(job, "execute", side_effect=execute), \
             patch.object(job.subprocess, "check_output", side_effect=["nix (Nix) 2.34.9\n", "false\n"]) as output, \
             patch("sys.stdout", new_callable=StringIO), patch("sys.stderr", new_callable=StringIO):
            with self.assertRaises(subprocess.CalledProcessError):
                job.validate(args)
            self.assertTrue(Path("evidence/flake-check.log").is_file())
            self.assertEqual(output.call_count, 2)
            self.assertEqual(output.call_args_list[0], unittest.mock.call(["nix", "--version"], text=True))
            self.assertIn("smoke ? planPart", output.call_args_list[1].args[0][-1])
            self.assertFalse(Path("evidence/launch.json").exists())

    def test_early_failure_still_writes_error_evidence_and_bounded_protocol(self):
        self.exit_code = 23
        def validate(_args):
            Path("evidence").mkdir()
            job.check_flake(Path("candidate"), Path("evidence"))
        with directory(), patch.object(job, "execute", side_effect=self.execute_check), \
             patch.object(job, "validate", side_effect=validate), \
             patch.object(sys, "argv", ["job.py", "--repository", "test/repo", "--head", "a" * 40,
                                        "--tools-ref", "pinned", "--compare", "compare.py"]), \
             patch("sys.stdout", new_callable=StringIO) as stdout, \
             patch("sys.stderr", new_callable=StringIO):
            self.assertEqual(job.main(), 2)
            self.assertEqual(json.loads(Path("evidence/status.json").read_text())["phase"], "error")
            self.assertEqual(Path("evidence/flake-check.log").read_bytes(), self.output + self.diagnostics)
            protocol = stdout.getvalue().splitlines()[-1]
            self.assertTrue(protocol.startswith("TVP_CI_RESULT="))
            self.assertLess(len(protocol.encode()), 4096)


class ResultProtocol(unittest.TestCase):
    def test_full_catalogue_pass_survives_buildbot_line_limit(self):
        result = {"phase": "passed", "counts": {"passed": 2000},
                  "testCounts": {"passed": 15000},
                  "jobs": {f"package_{i}": {"status": "passed", "log": "x" * 200}
                           for i in range(2000)}}
        def validate(args):
            Path("evidence").mkdir()
            Path("evidence/status.json").write_text(json.dumps(result))
            return result, 0
        with directory(), patch.object(job, "validate", side_effect=validate), \
             patch.object(sys, "argv", ["job.py", "--repository", "test/repo", "--head", "a" * 40,
                                        "--tools-ref", "pinned", "--compare", "compare.py"]), \
             patch("sys.stdout", new_callable=StringIO) as stdout:
            self.assertEqual(job.main(), 0)
            self.assertEqual(json.loads(Path("evidence/status.json").read_text()), result)
            line = stdout.getvalue()
        self.assertLess(len(line.encode()), 4096)
        self.assertEqual(result_properties(0, line, "")["ci_summary"],
                         "2000/2000 suites; 15000/15000 tests")

    def test_many_failures_keep_totals_and_a_failure_name(self):
        result = {"phase": "failed", "counts": {"passed": 1000, "failed-or-blocked": 1000},
                  "testCounts": {"passed": 10000, "failed-or-blocked": 1000},
                  "jobs": {f"package_{i}": {"status": "failed-or-blocked"} for i in range(1000)}}
        line = "TVP_CI_RESULT=" + job.result_record(result)
        self.assertLess(len(line.encode()), 4096)
        self.assertEqual(result_properties(1, line, "")["ci_summary"].split("; failed: ")[0],
                         "1000/2000 suites; 10000/11000 tests")
        self.assertIn("package_0", result_properties(1, line, "")["ci_summary"])

    def test_unicode_error_and_failure_names_remain_bounded(self):
        result = {"phase": "error", "error": "\u4e00" * 1000,
                  "jobs": {"\u4e00" * 1000: {"status": "failed-or-blocked"}}}
        line = "TVP_CI_RESULT=" + job.result_record(result)
        self.assertLess(len(line.encode()), 4096)
        self.assertNotIn("Invalid", result_properties(1, line, "")["ci_summary"])


if __name__ == '__main__':
    unittest.main()
