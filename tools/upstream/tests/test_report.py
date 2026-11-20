import os
import runpy
import unittest
from pathlib import Path


report_path = os.environ.get("TVP_UPSTREAM_REPORT_SCRIPT")
describe = runpy.run_path(report_path or str(Path(__file__).parents[1] / "report.py"))["describe"]


class UpstreamReportTests(unittest.TestCase):
    def observation(self, upstream=None, status="ok", listing=None, php=None):
        return {
            "row": {
                "pname": "fixture",
                "versions": ["2.4.1", "2.4.10", "2.5.2"],
                "upstream": upstream,
                "php": php,
            },
            "status": status,
            "error": "",
            "listing": listing,
            "head": None,
        }

    def test_classification_respects_maintenance_series_and_source_policy(self):
        current = self.observation(
            upstream={
                "type": "git-tags",
                "url": "https://upstream.example/fixture?private=value#tag",
                "unavailable": [{"versions": ["2.5.3", "2.5.4"], "reason": "Withdrawn"}],
            },
            listing={
                "included": ["1.9.1", "2.4.2", "2.4.10", "2.4.11", "2.5.3", "2.5.7", "2.6.0", "2.5.10a1"],
                "excluded": ["2.5.6", "2.5.11-rc.1", "refs/heads/next"],
            },
        )
        described = describe(current, "")
        releases = {row["version"]: row["status"] for row in described["releases"]}
        self.assertEqual(described["source"]["url"], "https://upstream.example/fixture")
        self.assertEqual(
            releases,
            {
                "1.9.1": "historical-gap",
                "2.4.1": "packaged",
                "2.4.2": "historical-gap",
                "2.4.10": "packaged",
                "2.4.11": "candidate",
                "2.5.2": "packaged",
                "2.5.3": "unavailable",
                "2.5.4": "unavailable",
                "2.5.6": "unsupported",
                "2.5.7": "candidate",
                "2.5.10a1": "prerelease",
                "2.5.11-rc.1": "prerelease",
                "2.6.0": "unsupported",
            },
        )
        self.assertEqual(next(r["reason"] for r in described["releases"] if r["version"] == "2.5.3"), "Withdrawn")

    def test_php_unknown_requirements_and_declared_coverage(self):
        current = self.observation(
            upstream={"type": "git-tags", "url": "https://example.invalid"},
            listing={"included": ["2.5.3"], "excluded": []},
            php={
                "kind": "independent",
                "rows": [
                    {"php": "8.2.1", "release": "2.5.2", "state": "gap"},
                    {
                        "php": "8.2.2",
                        "release": "2.5.2",
                        "state": "incompatible",
                        "reason": "Hard limit",
                        "source": "https://user:password@example.invalid/pkg",
                    },
                    {"php": "8.5.0", "release": "2.5.2", "state": "packaged"},
                ],
            },
        )
        result = describe(current, "8.2")
        self.assertEqual([row["state"] for row in result["php"]["rows"]], ["gap", "incompatible"])
        self.assertIsNone(result["php"]["rows"][1]["source"])
        self.assertEqual(result["releases"][-1]["status"], "unknown-compatibility")
        with self.assertRaisesRegex(ValueError, "no declared PHP version"):
            describe(current, "8.7")

    def test_git_head_uses_full_commit_identity(self):
        old, new = "1" * 40, "2" * 40
        current = self.observation(upstream={
            "type": "git-head", "url": "./local-checkout", "revisions": {"2026-11-20": old},
        })
        current["head"] = {"missingRevision": new}
        result = describe(current, "")
        self.assertIsNone(result["source"]["url"])
        self.assertEqual(result["releases"], [
            {"kind": "commit", "version": old, "status": "packaged"},
            {"kind": "commit", "version": new, "status": "candidate"},
        ])
        current["row"]["upstream"]["url"] = "git://mirror.example/config.git"
        self.assertEqual(
            describe(current, "")["source"]["url"], "git://mirror.example/config.git",
        )

    def test_missing_discovery_never_creates_candidates(self):
        missing = describe(self.observation(status="unconfigured"), "")
        self.assertEqual(missing["discoveryStatus"], "unconfigured")
        self.assertIsNone(missing["source"])
        self.assertTrue(all(row["status"] == "packaged" for row in missing["releases"]))
        error = self.observation(status="error", upstream={"type": "git-tags", "url": "https://example.invalid"})
        error["error"] = "could not read upstream listing"
        self.assertEqual(describe(error, "")["error"], error["error"])


if __name__ == "__main__":
    unittest.main()
