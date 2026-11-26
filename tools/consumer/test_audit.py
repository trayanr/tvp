"""Public offline checks for audit coverage, provenance and CI policy."""

from copy import deepcopy
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from audit import audit, components, exit_status, format_audit, format_prioritization, package_identity


PROFILE = {
    "schema": 1,
    "purl": "pkg:gem/example",
    "osv": {"ecosystem": "RubyGems", "name": "example"},
}


def selection(selector="example", *, drv="example.drv", profile=PROFILE):
    return {
        "pname": "example", "version": "1.0.0", "drvPath": "/nix/store/" + drv,
        "outputName": "out", "namespace": "packages", "selector": selector,
        "kind": "exact", "security": deepcopy(profile),
        "usedBy": [{"location": "output.tvpInventory.packages.runtime", "role": "package"}],
    }


def inventory(*packages):
    return {
        "schema": 1, "scope": "direct", "attribute": "devShells.x86_64-linux.default",
        "input": {"name": "tvp", "locked": {"rev": "frozen-tvp-revision"}},
        "packages": list(packages),
    }


class AuditTests(unittest.TestCase):
    def provider(self, callback, backend="osv"):
        def scan(values, **kwargs):
            return {
                "backend": {"name": backend, "version": "v1"},
                "database": {"retrievedAt": "2026-01-01T00:00:00Z", "offline": True},
                "results": callback(values),
            }
        return patch("audit.importlib.import_module", return_value=SimpleNamespace(scan=scan))

    def test_same_build_keeps_aliases_but_distinct_builds_stay_separate(self):
        selected = inventory(selection(), selection("example_exact"), selection(drv="other.drv"))
        resolved = components(selected)
        self.assertEqual(len(resolved), 2)
        self.assertEqual(len(resolved[0]["selections"]), 2)
        self.assertNotEqual(resolved[0]["id"], resolved[1]["id"])
        self.assertEqual(resolved[0]["identity"]["purl"], "pkg:gem/example@1.0.0")
        self.assertIn("usedBy", resolved[0]["selections"][0])

    def test_upstream_release_spelling_is_explicit_and_does_not_change_tvp_version(self):
        profile = {"schema": 1, "forVersion": "1.0.0", "upstreamVersion": "1.0-0",
                   "purl": "pkg:generic/example", "cpe": {"vendor": "example", "product": "example"}}
        selected = components(inventory(selection(profile=profile)))[0]
        self.assertEqual(selected["version"], "1.0.0")
        self.assertEqual(selected["identity"]["version"], "1.0-0")
        self.assertEqual(selected["identity"]["purl"], "pkg:generic/example@1.0-0")
        self.assertIn(":1.0-0:", selected["identity"]["cpe"])

    def test_profile_validation_and_conflicting_aliases(self):
        bad = [True, {"schema": True}, {"schema": 2}, {"schema": 1, "purl": "pkg:gem/example@1"},
               {"schema": 1, "upstreamVersion": "1.0-0"},
               {"schema": 1, "osv": {"ecosystem": "GIT", "name": "https://example.invalid/repo", "version": "v1"}},
               {"schema": 1, "cpe": {"vendor": "*", "product": "example"}},
               {"schema": 1, "osv": {"name": "example"}}]
        for profile in bad:
            with self.subTest(profile=profile), self.assertRaises(ValueError):
                package_identity(profile, "1.0.0")
        with self.assertRaisesRegex(ValueError, "Conflicting"):
            components(inventory(selection(), selection("alias", profile=None)))
        self.assertEqual(package_identity(None, "1.0.0"), {})
        self.assertEqual(package_identity(PROFILE, None), {})
        profile = {"schema": 1, "cpe": {"vendor": "example", "product": "example"}}
        self.assertIn(":1.0\\+patched:", package_identity(profile, "1.0+patched")["cpe"])

    def test_version_bound_profile_cannot_reuse_an_osv_tag_for_an_override(self):
        profile = {**PROFILE, "forVersion": "1.0.0",
                   "osv": {"ecosystem": "GIT", "name": "https://example.invalid/project", "version": "v1_0_0"}}
        identity = package_identity(profile, "1.0.0")
        self.assertEqual(identity["osv"]["version"], "v1_0_0")
        self.assertEqual(package_identity(profile, "1.0.1"), {})
        for value in (None, "", True, " ", "1.0\n0"):
            with self.subTest(value=value), self.assertRaisesRegex(ValueError, "forVersion"):
                package_identity({**profile, "forVersion": value}, "1.0.0")

    def test_multiple_cpe_product_identities_are_explicit_and_distinct(self):
        profile = {"schema": 1, "cpes": [
            {"vendor": "example", "product": "tool"},
            {"vendor": "example", "product": "library"},
        ]}
        identity = package_identity(profile, "1.0.0")
        self.assertEqual(identity["cpes"], [
            "cpe:2.3:a:example:tool:1.0.0:*:*:*:*:*:*:*",
            "cpe:2.3:a:example:library:1.0.0:*:*:*:*:*:*:*",
        ])
        self.assertNotIn("cpe", identity)
        for values in (None, [], {}, [None], [profile["cpes"][0]] * 2,
                       [{"vendor": "example", "product": "tool"},
                        {"part": "a", "vendor": "example", "product": "tool"}]):
            with self.subTest(values=values), self.assertRaises(ValueError):
                package_identity({"schema": 1, "cpes": values}, "1.0.0")
        with self.assertRaisesRegex(ValueError, "choose cpe or cpes"):
            package_identity({**profile, "cpe": profile["cpes"][0]}, "1.0.0")

    def test_findings_remain_unassessed_and_ci_policy_is_explicit(self):
        def results(values):
            return [{"component": value["id"], "status": "scanned", "vulnerabilities": [{
                "id": "TEST-ADVISORY-1", "severity": "high", "summary": "Synthetic advisory",
                "aliases": ["TEST-ALIAS-1"], "fixedVersions": ["1.0.1"],
                "url": "https://example.invalid/advisory", "match": "osv-ecosystem-version",
            }]} for value in values]
        with self.provider(results):
            report = audit(inventory(selection()), "osv", offline=True)
        self.assertEqual(report["input"]["locked"]["rev"], "frozen-tvp-revision")
        self.assertEqual(report["findings"][0]["applicability"], "unassessed")
        self.assertEqual(exit_status(report), 0)
        self.assertEqual(exit_status(report, fail_on="high"), 2)
        self.assertEqual(exit_status(report, fail_on="critical"), 0)
        self.assertFalse(report["scope"]["environmentComplete"])
        self.assertIn("applicability unassessed", format_audit(report))

    def test_missing_identity_and_empty_inventory_do_not_look_clean(self):
        def results(values):
            return [{"component": value["id"], "status": "unsupported", "reason": "No OSV identity",
                     "vulnerabilities": []} for value in values]
        for selected in (inventory(selection(profile=None)), inventory()):
            with self.subTest(selected=selected), self.provider(results):
                report = audit(selected, "osv", offline=True)
                self.assertFalse(report["coverage"]["completeForInventory"])
                self.assertEqual(exit_status(report, require_coverage=True), 3)
                self.assertIn("No components were scanned", format_audit(report))
                self.assertNotIn("No advisory matches", format_audit(report))

    def test_prioritization_is_preserved_and_displayed_with_its_limits(self):
        signals = {
            "knownExploited": [{"cve": "CVE-2099-0001", "dateAdded": "2026-11-01",
                                "knownRansomwareCampaignUse": "known",
                                "requiredAction": "Apply the vendor fix", "dueDate": "2026-11-22"}],
            "epss": [{"cve": "CVE-2099-0001", "epss": 0.125,
                      "percentile": 0.9, "date": "2026-11-25"}],
            "risk": {"source": "grype", "score": 74.5},
        }
        def results(values):
            return [{"component": value["id"], "status": "scanned", "vulnerabilities": [{
                "id": "TEST-ADVISORY", "severity": "high", **deepcopy(signals),
            }]} for value in values]
        with self.provider(results, backend="grype"):
            report = audit(inventory(selection()), "grype", offline=True)
        finding = report["findings"][0]
        for key, expected in signals.items():
            self.assertEqual(finding[key], expected)
        report["database"]["providers"] = {
            "kev": {"captured": "2026-11-26T00:22:41Z"},
            "epss": {"captured": "2026-11-26T00:32:00Z"},
        }
        text = format_audit(report)
        self.assertIn("CISA KEV: CVE-2099-0001 listed; added 2026-11-01; ransomware use: known", text)
        self.assertIn("EPSS CVE-2099-0001: 12.50%; percentile 90.00; scored 2026-11-25", text)
        self.assertIn("Grype risk: 74.5/100 (scanner prioritization)", text)
        self.assertIn("CISA KEV data captured: 2026-11-26T00:22:41Z", text)
        self.assertIn("EPSS data captured: 2026-11-26T00:32:00Z", text)
        self.assertIn("global exploitation activity over the next 30 days", text)
        self.assertIn("Missing threat data is unknown", text)
        self.assertIn("applicability unassessed", text)

    def test_zero_and_missing_prioritization_values_are_distinct(self):
        self.assertEqual(format_prioritization({}), [])
        self.assertEqual(format_prioritization({"knownExploited": [], "epss": []}), [])
        lines = format_prioritization({
            "epss": [{"cve": "CVE-2099-0001", "epss": 0, "percentile": 0}],
            "risk": {"source": "grype", "score": 0},
        })
        self.assertEqual(lines, ["EPSS CVE-2099-0001: 0.00%; percentile 0.00",
                                 "Grype risk: 0/100 (scanner prioritization)"])

    def test_discovered_output_origins_survive_component_deduplication(self):
        first = selection()
        second = selection("alias")
        first["usedBy"][0]["attribute"] = "devShells.x86_64-linux.default"
        second["usedBy"][0]["attribute"] = "packages.x86_64-linux.example"
        selected = inventory(first, second)
        selected.update(attribute=None, scope="discovered", system="x86_64-linux",
                        outputs=[{"attribute": name, "status": "evaluated"} for name in (
                            "devShells.x86_64-linux.default", "packages.x86_64-linux.example")],
                        skippedOutputs=[{"attribute": "apps", "reason": "app inventory requires an adapter"}],
                        outputCoverage={"evaluated": 2, "failed": 0, "complete": True})
        def results(values):
            self.assertEqual(len(values), 1)
            return [{"component": values[0]["id"], "status": "scanned", "vulnerabilities": [{
                "id": "TEST-ADVISORY", "severity": "high",
            }]}]
        with self.provider(results):
            report = audit(selected, "osv", offline=True)
        self.assertEqual(report["coverage"]["total"], 1)
        self.assertTrue(report["coverage"]["completeForInventory"])
        self.assertEqual(report["outputs"], selected["outputs"])
        self.assertEqual(report["skippedOutputs"], selected["skippedOutputs"])
        self.assertEqual(report["outputCoverage"], selected["outputCoverage"])
        text = format_audit(report)
        self.assertIn("Outputs: devShells.x86_64-linux.default, packages.x86_64-linux.example", text)

    def test_failed_output_keeps_partial_findings_and_causes_an_error_exit(self):
        selected = inventory(selection())
        selected["packages"][0]["usedBy"][0]["attribute"] = "packages.x86_64-linux.good"
        selected.update(attribute=None, scope="discovered", system="x86_64-linux",
                        outputs=[{"attribute": "packages.x86_64-linux.good", "status": "evaluated"},
                                 {"attribute": "packages.x86_64-linux.broken", "status": "failed",
                                  "error": "synthetic evaluation failure"}],
                        skippedOutputs=[], outputCoverage={"evaluated": 1, "failed": 1, "complete": False})
        def results(values):
            return [{"component": values[0]["id"], "status": "scanned", "vulnerabilities": [{
                "id": "TEST-ADVISORY", "severity": "critical",
            }]}]
        with self.provider(results):
            report = audit(selected, "osv", offline=True)
        self.assertEqual(len(report["findings"]), 1)
        self.assertFalse(report["coverage"]["completeForInventory"])
        self.assertEqual(exit_status(report), 1)
        self.assertEqual(exit_status(report, fail_on="high"), 1)
        self.assertEqual(exit_status(report, require_coverage=True), 1)
        self.assertIn("synthetic evaluation failure", format_audit(report))

    def test_threat_scores_do_not_filter_findings_or_change_severity_gates(self):
        for severity, probability, risk, expected in (("high", 0, 0, 2), ("low", 1, 100, 0)):
            def results(values):
                return [{"component": values[0]["id"], "status": "scanned", "vulnerabilities": [{
                    "id": "TEST-ADVISORY", "severity": severity,
                    "epss": [{"cve": "CVE-2099-0001", "epss": probability}],
                    "risk": {"source": "grype", "score": risk},
                }]}]
            with self.subTest(severity=severity), self.provider(results, backend="grype"):
                report = audit(inventory(selection()), "grype", offline=True)
                self.assertEqual(len(report["findings"]), 1)
                self.assertEqual(exit_status(report), 0)
                self.assertEqual(exit_status(report, fail_on="high"), expected)

    def test_backend_cannot_silently_drop_components_or_unknown_severity(self):
        with self.provider(lambda _: []), self.assertRaisesRegex(ValueError, "omitted"):
            audit(inventory(selection()), "osv")
        def unknown(values):
            return [{"component": values[0]["id"], "status": "scanned", "vulnerabilities": [{
                "id": "TEST-ADVISORY-UNKNOWN", "severity": "unknown", "fixedVersions": [],
            }]}]
        with self.provider(unknown):
            report = audit(inventory(selection()), "osv")
        self.assertEqual(report["findings"][0]["severity"], "unknown")
        self.assertIn("UNKNOWN", format_audit(report))

    def test_distinct_provider_evidence_for_the_same_advisory_is_retained(self):
        def results(values):
            return [{"component": values[0]["id"], "status": "scanned", "vulnerabilities": [
                {"id": "TEST-ADVISORY", "severity": "high", "namespace": namespace}
                for namespace in ("provider-one", "provider-two")
            ]}]
        with self.provider(results):
            report = audit(inventory(selection()), "osv")
        self.assertEqual(len(report["findings"]), 2)


if __name__ == "__main__":
    unittest.main()
