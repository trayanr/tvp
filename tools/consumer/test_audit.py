"""Public offline checks for audit coverage, provenance and CI policy."""

from copy import deepcopy
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from audit import audit, components, exit_status, format_audit, package_identity


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
    def provider(self, callback):
        def scan(values, **kwargs):
            return {
                "backend": {"name": "osv", "version": "v1"},
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

    def test_profile_validation_and_conflicting_aliases(self):
        bad = [True, {"schema": True}, {"schema": 2}, {"schema": 1, "purl": "pkg:gem/example@1"},
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
