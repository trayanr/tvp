"""Offline contract tests for the explicit-component Grype candidate adapter."""

import copy
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import audit_grype


COMPONENT = {
    "id": "tvp-curl-build-a", "name": "curl", "version": "8.0.0",
    "identity": {"purl": "pkg:generic/curl@8.0.0", "cpe": "cpe:2.3:a:haxx:curl:8.0.0:*:*:*:*:*:*:*"},
}
DOCUMENT = {
    "descriptor": {"name": "grype", "version": "0.119.0", "db": {
        "schemaVersion": "6.1.10", "built": "2026-11-26T08:00:00Z", "valid": True,
    }},
    "matches": [{
        "artifact": {"id": "grype-generated-content-id", "name": "curl", "version": "8.0.0",
                     "purl": "pkg:generic/curl@8.0.0", "cpes": [COMPONENT["identity"]["cpe"]]},
        "vulnerability": {"id": "CVE-TEST-1", "severity": "High", "description": "Synthetic finding",
                          "namespace": "nvd:cpe", "dataSource": "https://example.invalid/CVE-TEST-1",
                          "fix": {"versions": ["8.1.0"], "state": "fixed"}},
        "relatedVulnerabilities": [{"id": "GHSA-test-related"}],
        "matchDetails": [{"type": "cpe-match", "matcher": "stock-matcher"}],
    }],
}


class GrypeAdapterTests(unittest.TestCase):
    def invoke(self, document=None, components=None, **kwargs):
        document = copy.deepcopy(DOCUMENT if document is None else document)
        components = copy.deepcopy([COMPONENT] if components is None else components)
        captured = {}

        def run(command, **options):
            captured.update(command=command, **options)
            captured["sbom"] = json.loads(Path(command[1].removeprefix("sbom:")).read_text())
            captured["configuration"] = json.loads(Path(command[-1]).read_text())
            return subprocess.CompletedProcess(command, 0, json.dumps(document), "")

        with patch("audit_grype.shutil.which", return_value="/test/bin/grype"), \
                patch("audit_grype.subprocess.run", side_effect=run) as mocked:
            result = audit_grype.scan(components, **kwargs)
        return result, captured, mocked

    def test_explicit_sbom_and_result_mapping_keep_build_variants(self):
        second = copy.deepcopy(COMPONENT)
        second["id"] = "tvp-curl-build-b"
        unsupported = {"id": "unknown", "name": "unmapped", "version": "1", "identity": {}}
        document = copy.deepcopy(DOCUMENT)
        document["matches"].append(copy.deepcopy(document["matches"][0]))
        result, captured, _ = self.invoke(document, [COMPONENT, second, unsupported])
        self.assertEqual(captured["sbom"]["bomFormat"], "CycloneDX")
        self.assertEqual(captured["sbom"]["specVersion"], "1.6")
        self.assertEqual([c["bom-ref"] for c in captured["sbom"]["components"]], [COMPONENT["id"], second["id"]])
        self.assertNotIn("distro", captured["sbom"])
        self.assertEqual(captured["sbom"]["components"][0]["cpe"], COMPONENT["identity"]["cpe"])
        self.assertEqual(result["backend"], {"name": "grype", "version": "0.119.0"})
        self.assertEqual(result["database"]["descriptor"], DOCUMENT["descriptor"]["db"])
        for row in result["results"][:2]:
            self.assertEqual(row["status"], "scanned")
            self.assertEqual(len(row["vulnerabilities"]), 1)
            finding = row["vulnerabilities"][0]
            self.assertEqual(finding["severity"], "high")
            self.assertEqual(finding["fixedVersions"], ["8.1.0"])
            self.assertEqual(finding["aliases"], [])
            self.assertEqual(finding["relatedIds"], ["GHSA-test-related"])
        self.assertEqual(result["results"][2]["status"], "unsupported")

    def test_cpe_only_matching_and_unknown_severity_without_fix(self):
        component = copy.deepcopy(COMPONENT)
        del component["identity"]["purl"]
        document = copy.deepcopy(DOCUMENT)
        document["matches"][0]["artifact"]["purl"] = ""
        vulnerability = document["matches"][0]["vulnerability"]
        vulnerability["severity"] = "Unknown"
        vulnerability["fix"] = {"versions": [], "state": "not-fixed"}
        result, _, _ = self.invoke(document, [component])
        finding = result["results"][0]["vulnerabilities"][0]
        self.assertEqual(finding["severity"], "unknown")
        self.assertEqual(finding["fixedVersions"], [])

    def test_current_database_status_and_provider_provenance_are_retained(self):
        document = copy.deepcopy(DOCUMENT)
        status = document["descriptor"]["db"]
        providers = {"nvd": {"captured": "2026-11-26T00:00:00Z", "input": "test-digest"}}
        document["descriptor"]["db"] = {"status": status, "providers": providers}
        result, _, _ = self.invoke(document)
        self.assertEqual(result["database"]["descriptor"], status)
        self.assertEqual(result["database"]["providers"], providers)
        self.assertEqual(len(result["database"]["responseSha256"]), 64)

    def test_known_exploitation_and_epss_are_preserved_with_grype_risk(self):
        document = copy.deepcopy(DOCUMENT)
        signals = {
            "knownExploited": [{
                "cve": "CVE-2024-12345", "vendorProject": "Synthetic vendor", "product": "curl",
                "dateAdded": "2026-11-20", "dueDate": "2026-12-11",
                "requiredAction": "Apply the upstream fix.", "knownRansomwareCampaignUse": "known",
                "notes": "Synthetic public fixture.", "urls": ["https://example.invalid/advisory"],
                "cwes": ["CWE-20"],
            }],
            "epss": [{"cve": "CVE-2024-12345", "epss": 0.74, "percentile": 0.98, "date": "2026-11-25"}],
            "risk": 94.5,
        }
        document["matches"][0]["vulnerability"].update(signals)
        providers = {"kev": {"captured": "2026-11-26T00:22:41Z", "input": "synthetic-kev-digest"},
                     "epss": {"captured": "2026-11-26T00:21:29Z", "input": "synthetic-epss-digest"}}
        document["descriptor"]["db"] = {"status": document["descriptor"]["db"], "providers": providers}
        result, _, _ = self.invoke(document)
        finding = result["results"][0]["vulnerabilities"][0]
        self.assertEqual(finding["knownExploited"], signals["knownExploited"])
        self.assertEqual(finding["epss"], signals["epss"])
        self.assertEqual(finding["risk"], {"source": "grype", "score": 94.5})
        self.assertEqual(result["database"]["providers"], providers)

    def test_absent_and_null_risk_metadata_is_optional(self):
        for signals in ({}, {"knownExploited": None, "epss": None, "risk": None}):
            with self.subTest(signals=signals):
                document = copy.deepcopy(DOCUMENT)
                document["matches"][0]["vulnerability"].update(signals)
                result, _, _ = self.invoke(document)
                finding = result["results"][0]["vulnerabilities"][0]
                for field in ("knownExploited", "epss", "risk"):
                    self.assertNotIn(field, finding)

    def test_zero_scores_and_empty_signal_lists_are_retained(self):
        document = copy.deepcopy(DOCUMENT)
        document["matches"][0]["vulnerability"].update({
            "knownExploited": [], "epss": [{"cve": "CVE-2024-12345", "epss": 0, "percentile": 0}],
            "risk": 0,
        })
        result, _, _ = self.invoke(document)
        finding = result["results"][0]["vulnerabilities"][0]
        self.assertEqual(finding["knownExploited"], [])
        self.assertEqual(finding["epss"][0]["epss"], 0)
        self.assertEqual(finding["epss"][0]["percentile"], 0)
        self.assertEqual(finding["risk"], {"source": "grype", "score": 0})
        document["matches"][0]["vulnerability"]["epss"] = []
        result, _, _ = self.invoke(document)
        self.assertEqual(result["results"][0]["vulnerabilities"][0]["epss"], [])
        probability_only = {"cve": "CVE-2024-12345", "epss": 0.25}
        document["matches"][0]["vulnerability"]["epss"] = [probability_only]
        result, _, _ = self.invoke(document)
        self.assertEqual(result["results"][0]["vulnerabilities"][0]["epss"], [probability_only])

    def test_malformed_signal_records_require_cve_identity(self):
        for field in ("knownExploited", "epss"):
            for value in ({}, "not a list", [None], [{}], [{"cve": ""}], [{"cve": 123}],
                          [{"cve": "GHSA-example"}], [{"cve": "CVE-2024-12345\n"}]):
                with self.subTest(field=field, value=value), self.assertRaisesRegex(ValueError, field):
                    document = copy.deepcopy(DOCUMENT)
                    document["matches"][0]["vulnerability"][field] = value
                    self.invoke(document)

    def test_supplied_signal_dates_must_be_iso_calendar_dates(self):
        cases = [("knownExploited", "dateAdded"), ("knownExploited", "dueDate"), ("epss", "date")]
        for field, key in cases:
            for value in ("2026-02-30", "20261125", "2026-11-25T00:00:00Z", "", None, 20261125):
                with self.subTest(field=field, key=key, value=value), self.assertRaisesRegex(ValueError, key):
                    document = copy.deepcopy(DOCUMENT)
                    record = {"cve": "CVE-2024-12345", key: value}
                    if field == "epss":
                        record.update(epss=0.5, percentile=0.9)
                    document["matches"][0]["vulnerability"][field] = [record]
                    self.invoke(document)

    def test_signal_scores_reject_nonfinite_out_of_range_and_boolean_values(self):
        for field, maximum in (("risk", 100), ("epss", 1), ("percentile", 1)):
            for value in (-0.1, maximum + 0.1, float("nan"), float("inf"), -float("inf"), True, "0.5", []):
                with self.subTest(field=field, value=value), self.assertRaisesRegex(ValueError, field):
                    document = copy.deepcopy(DOCUMENT)
                    vulnerability = document["matches"][0]["vulnerability"]
                    if field == "risk":
                        vulnerability["risk"] = value
                    else:
                        record = {"cve": "CVE-2024-12345", "epss": 0.5, "percentile": 0.9, field: value}
                        vulnerability["epss"] = [record]
                    self.invoke(document)
        document = copy.deepcopy(DOCUMENT)
        document["matches"][0]["vulnerability"]["epss"] = [{"cve": "CVE-2024-12345", "percentile": 0.9}]
        with self.assertRaisesRegex(ValueError, "epss"):
            self.invoke(document)

    def test_known_exploitation_text_and_list_fields_have_valid_shapes(self):
        for field, value in (("requiredAction", 12), ("knownRansomwareCampaignUse", True),
                             ("notes", []), ("vendorProject", None), ("product", {}),
                             ("urls", "https://example.invalid"), ("urls", [12]),
                             ("cwes", None), ("cwes", [""])):
            with self.subTest(field=field, value=value), self.assertRaisesRegex(ValueError, field):
                document = copy.deepcopy(DOCUMENT)
                document["matches"][0]["vulnerability"]["knownExploited"] = [{"cve": "CVE-2024-12345", field: value}]
                self.invoke(document)

    def test_package_cpe_aliases_scan_cli_and_library_without_duplicate_findings(self):
        component = copy.deepcopy(COMPONENT)
        library = "cpe:2.3:a:haxx:libcurl:8.0.0:*:*:*:*:*:*:*"
        component["identity"] = {"purl": COMPONENT["identity"]["purl"],
                                 "cpes": [COMPONENT["identity"]["cpe"], library]}
        document = copy.deepcopy(DOCUMENT)
        document["matches"][0]["artifact"]["cpes"] = [library]
        result, captured, _ = self.invoke(document, [component])
        self.assertEqual([row["cpe"] for row in captured["sbom"]["components"]], component["identity"]["cpes"])
        self.assertEqual(len({row["bom-ref"] for row in captured["sbom"]["components"]}), 2)
        self.assertEqual(len(result["results"][0]["vulnerabilities"]), 1)

    def test_declared_upstream_version_is_used_without_relabelling_the_tvp_component(self):
        component = copy.deepcopy(COMPONENT)
        component["version"] = "8.0.0.0"
        component["identity"]["version"] = "8.0.0"
        result, captured, _ = self.invoke(components=[component])
        self.assertEqual(captured["sbom"]["components"][0]["version"], "8.0.0")
        self.assertEqual(result["results"][0]["component"], component["id"])
        self.assertEqual(result["results"][0]["status"], "scanned")

    def test_backend_environment_and_config_cannot_hide_results(self):
        inherited = {"GRYPE_ONLY_FIXED": "true", "GRYPE_CONFIG": "/host/ignore.yaml",
                     "GRYPE_VEX_DOCUMENTS": "/host/vex.json", "GRYPE_FILE": "/host/report.json",
                     "SYFT_DEFAULT_CATALOGERS": "none", "PATH": "/test/bin"}
        with tempfile.TemporaryDirectory() as cache, patch.dict(os.environ, inherited, clear=True):
            result, captured, _ = self.invoke(offline=True, cache_dir=cache)
        self.assertEqual(captured["env"]["GRYPE_DB_AUTO_UPDATE"], "false")
        self.assertEqual(captured["env"]["GRYPE_CHECK_FOR_APP_UPDATE"], "false")
        self.assertEqual(captured["env"]["GRYPE_EXTERNAL_SOURCES_ENABLE"], "false")
        self.assertEqual(captured["env"]["GRYPE_DB_CACHE_DIR"], str(Path(cache)/"grype"))
        self.assertNotIn("GRYPE_ONLY_FIXED", captured["env"])
        self.assertNotIn("GRYPE_CONFIG", captured["env"])
        self.assertNotIn("GRYPE_VEX_DOCUMENTS", captured["env"])
        self.assertNotIn("SYFT_DEFAULT_CATALOGERS", captured["env"])
        self.assertFalse(captured["configuration"]["db"]["auto-update"])
        self.assertFalse(captured["configuration"]["external-sources"]["enable"])
        self.assertEqual(captured["configuration"]["ignore"], [])
        self.assertTrue(result["database"]["offline"])

    def test_invalid_identities_are_unsupported_without_invoking_grype(self):
        invalid = [
            {**COMPONENT, "version": None},
            {**COMPONENT, "identity": {"purl": "pkg:generic/curl"}},
            {**COMPONENT, "identity": {"purl": "pkg:generic/curl@9.0.0"}},
            {**COMPONENT, "identity": {"purl": "pkg:generic/curl@8.0.0"}},
            {**COMPONENT, "identity": {"cpe": "cpe:2.3:a:haxx:curl:*:*:*:*:*:*:*:*"}},
            {**COMPONENT, "identity": {}},
        ]
        for component in invalid:
            with self.subTest(component=component), patch("audit_grype.shutil.which") as which:
                result = audit_grype.scan([component])
                self.assertEqual(result["results"][0]["status"], "unsupported")
                self.assertFalse(result["database"]["used"])
                which.assert_not_called()

    def test_malformed_or_filtered_results_fail_instead_of_reporting_clean(self):
        cases = []
        document = copy.deepcopy(DOCUMENT)
        document.pop("matches")
        cases.append(document)
        document = copy.deepcopy(DOCUMENT)
        document["descriptor"].pop("db")
        cases.append(document)
        document = copy.deepcopy(DOCUMENT)
        document["descriptor"]["db"]["valid"] = False
        cases.append(document)
        document = copy.deepcopy(DOCUMENT)
        document["descriptor"]["version"] = ""
        cases.append(document)
        document = copy.deepcopy(DOCUMENT)
        document["ignoredMatches"] = [document["matches"][0]]
        cases.append(document)
        document = copy.deepcopy(DOCUMENT)
        document["matches"][0]["artifact"]["purl"] = "pkg:generic/unrelated@8.0.0"
        cases.append(document)
        document = copy.deepcopy(DOCUMENT)
        document["matches"][0]["artifact"]["cpes"] = []
        cases.append(document)
        document = copy.deepcopy(DOCUMENT)
        document["matches"][0]["matchDetails"] = []
        cases.append(document)
        document = copy.deepcopy(DOCUMENT)
        document["matches"][0]["vulnerability"]["fix"]["versions"] = "8.1.0"
        cases.append(document)
        for document in cases:
            with self.subTest(document=document), self.assertRaises(ValueError):
                self.invoke(document)

    def test_backend_failures_and_missing_tool_are_errors(self):
        with patch("audit_grype.shutil.which", return_value=None), self.assertRaisesRegex(RuntimeError, "PATH"):
            audit_grype.scan([COMPONENT])
        with patch("audit_grype.shutil.which", return_value="/bin/grype"):
            with patch("audit_grype.subprocess.run", side_effect=subprocess.TimeoutExpired("grype", 360)), \
                    self.assertRaisesRegex(RuntimeError, "timed out"):
                audit_grype.scan([COMPONENT])
            with patch("audit_grype.subprocess.run", return_value=subprocess.CompletedProcess("grype", 1, "", "database unavailable")), \
                    self.assertRaisesRegex(RuntimeError, "database unavailable"):
                audit_grype.scan([COMPONENT])
            with patch("audit_grype.subprocess.run", return_value=subprocess.CompletedProcess("grype", 0, "invalid", "")), \
                    self.assertRaisesRegex(ValueError, "invalid JSON"):
                audit_grype.scan([COMPONENT])


if __name__ == "__main__":
    unittest.main()
