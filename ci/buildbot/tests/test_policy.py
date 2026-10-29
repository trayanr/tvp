import json
from pathlib import Path
import sys
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from policy import eligible, result_properties, summary, graph_approval


def pull():
    return {"number": 17, "state": "open", "draft": False, "labels": [{"name": "ci:build"}],
            "head": {"sha": "a" * 40, "repo": {"full_name": "trayanr/tvp"}},
            "base": {"sha": "b" * 40, "ref": "master", "repo": {"full_name": "trayanr/tvp"}}}


class Admission(unittest.TestCase):
    def test_label_opts_in(self):
        self.assertTrue(eligible(pull(), "trayanr/tvp"))
        pr = pull(); pr["labels"] = []
        self.assertFalse(eligible(pr, "trayanr/tvp"))

    def test_drafts_closed_forks_and_wrong_target_are_not_scheduled(self):
        mutations = [("draft", True), ("state", "closed")]
        for key, value in mutations:
            pr = pull(); pr[key] = value
            self.assertFalse(eligible(pr, "trayanr/tvp"))
        for part, key, value in [("head", "repo", {"full_name": "outsider/tvp"}),
                                 ("head", "repo", None), ("base", "ref", "other"),
                                 ("head", "sha", "main"), ("base", "sha", "abc")]:
            pr = pull(); pr[part][key] = value
            self.assertFalse(eligible(pr, "trayanr/tvp"))

    def test_full_sha_changes_are_eligible_without_relabelling(self):
        pr = pull(); pr["head"]["sha"] = "c" * 40
        self.assertTrue(eligible(pr, "trayanr/tvp"))


class Reporting(unittest.TestCase):
    def test_failure_summary_names_current_failure(self):
        status = {"phase": "failed", "counts": {"passed": 9, "failed-or-blocked": 1},
                  "testCounts": {"passed": 40, "failed-or-blocked": 2},
                  "jobs": {"php_5_6_40": {"status": "failed-or-blocked"}}}
        self.assertEqual(summary(status), "9/10 suites; 40/42 tests; failed: php_5_6_40")

    def test_description_is_bounded_and_missing_result_is_failure_information(self):
        self.assertLessEqual(len(summary({"phase": "error", "error": "x" * 1000})), 140)
        self.assertIn("interrupted", result_properties(1, "", "")["ci_summary"])
        self.assertIn("Invalid", result_properties(0, "TVP_CI_RESULT=bad", "")["ci_summary"])

    def test_process_failure_cannot_be_reported_as_pass(self):
        line = "TVP_CI_RESULT=" + json.dumps({"phase": "passed", "counts": {"passed": 1}})
        self.assertIn("process failed", result_properties(1, line, "")["ci_summary"])


class Approvals(unittest.TestCase):
    def test_approval_is_pinned_to_both_commits_and_pr(self):
        settings = {"graph_approvals": {"17:head:base": ["packages.php_7_4_33"]}}
        self.assertEqual(graph_approval(settings, 17, "head", "base"), ["packages.php_7_4_33"])
        for pr, head, base in [(18, "head", "base"), (17, "new", "base"), (17, "head", "new")]:
            self.assertEqual(graph_approval(settings, pr, head, base), [])

    def test_blanket_or_malformed_configuration_is_not_a_list_of_approvals(self):
        for value in ["all", [None], [""]]:
            with self.assertRaises(ValueError):
                graph_approval({"graph_approvals": {"1:h:b": value}}, 1, "h", "b")


if __name__ == '__main__':
    unittest.main()
