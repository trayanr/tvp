"""Offline checks for advisory controls and immutable candidate evidence."""

import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from evaluate_audit import evaluate, resolve_components, score, validate_matrix


def case(identifier, affected, *, selector=None):
    return {"id": identifier, "name": "example", "version": "1.0.0",
            "origin": "tvp-metadata" if selector else "upstream-version-control",
            **({"selector": selector} if selector else {}), "expectedAffected": affected,
            "advisory": {"id": "CVE-TEST", "aliases": ["GHSA-test"], "url": "https://example.invalid/advisory"}}


MATRIX = {"schema": 1, "cases": [case("affected", True), case("fixed", False), case("unmapped", False)]}


def report():
    return {"backend": {"name": "osv", "version": "v1"}, "database": {"source": "fixture"}, "results": [
        {"component": "evaluation-affected", "status": "scanned",
         "vulnerabilities": [{"id": "GHSA-test", "aliases": ["CVE-TEST"]}]},
        {"component": "evaluation-fixed", "status": "scanned", "vulnerabilities": [{"id": "OTHER-ADVISORY"}]},
        {"component": "evaluation-unmapped", "status": "unsupported", "reason": "No identity", "vulnerabilities": []},
    ]}


class AuditEvaluationTests(unittest.TestCase):
    def test_alias_detection_other_advisories_and_unsupported_controls(self):
        comparison = score(MATRIX, report())
        self.assertEqual(comparison["counts"], {
            "affected_detected": 1, "affected_missed": 0, "fixed_clear": 1,
            "fixed_matched": 0, "unsupported": 1,
        })
        self.assertEqual(comparison["cases"][1]["findingCount"], 1)
        self.assertFalse(comparison["cases"][1]["targetMatched"])

    def test_related_ids_are_not_aliases_and_fixed_matches_remain_visible(self):
        result = report()
        result["results"][0]["vulnerabilities"] = [{"id": "OTHER", "relatedIds": ["CVE-TEST"]}]
        result["results"][1]["vulnerabilities"] = [{"id": "CVE-TEST"}]
        comparison = score(MATRIX, result)
        self.assertEqual(comparison["counts"]["affected_missed"], 1)
        self.assertEqual(comparison["counts"]["fixed_matched"], 1)

    def test_invalid_and_incomplete_candidate_responses_are_errors(self):
        bad = []
        result = report()
        result["results"].pop()
        bad.append(result)
        result = report()
        result["results"].append(result["results"][0])
        bad.append(result)
        result = report()
        result["results"][0]["vulnerabilities"][0]["aliases"] = "CVE-TEST"
        bad.append(result)
        result = report()
        result["results"][2]["vulnerabilities"] = [{"id": "CVE-TEST"}]
        bad.append(result)
        for value in bad:
            with self.subTest(value=value), self.assertRaises(ValueError):
                score(MATRIX, value)

    def test_matrix_rejects_duplicate_ids_and_mislabelled_origins(self):
        invalid = [
            {"schema": True, "cases": MATRIX["cases"]},
            {"schema": 1, "cases": [case("one", True), case("one", False)]},
            {"schema": 1, "cases": [{**case("one", True), "origin": "tvp-metadata"}]},
            {"schema": 1, "cases": [{**case("one", True), "expectedAffected": 1}]},
        ]
        for matrix in invalid:
            with self.subTest(matrix=matrix), self.assertRaises(ValueError):
                validate_matrix(matrix)

    def test_resolver_uses_frozen_metadata_and_distinguishes_upstream_controls(self):
        matrix = {"schema": 1, "cases": [case("actual", True, selector="example_1"),
                                         {**case("control", False), "version": "2.0.0", "profileSelector": "example_1"}]}
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            snapshot = root / "snapshot"
            snapshot.mkdir()
            (snapshot / "flake.lock").write_text('{"frozen": true}')
            metadata = {"path": str(snapshot), "locked": {"narHash": "frozen-source"}}
            packages = {"example_1": {"pname": "example", "version": "1.0.0", "drvPath": "/nix/store/example.drv",
                                      "security": {"schema": 1, "purl": "pkg:generic/example"}}}
            with patch("evaluate_audit._nix_json", side_effect=[metadata, packages]) as nix:
                source, components = resolve_components(root, matrix)
            self.assertEqual(source["locked"]["narHash"], "frozen-source")
            self.assertEqual(nix.call_args.kwargs["env"]["TVP_EVALUATION_SOURCE"], str(snapshot))
            self.assertIn("allow-import-from-derivation", nix.call_args.args[0])
            self.assertIn("drvPath", components[0])
            self.assertNotIn("drvPath", components[1])
            self.assertEqual(components[1]["identity"]["purl"], "pkg:generic/example@2.0.0")
            packages["example_1"]["version"] = "9.0.0"
            with patch("evaluate_audit._nix_json", side_effect=[metadata, packages]), self.assertRaisesRegex(ValueError, "version differs"):
                resolve_components(root, matrix)

    def test_failure_is_preserved_other_candidate_runs_and_evidence_cannot_be_overwritten(self):
        components = [{"id": "evaluation-" + row["id"]} for row in MATRIX["cases"]]
        failed = SimpleNamespace(scan=lambda *args, **kwargs: (_ for _ in ()).throw(RuntimeError("database unavailable")))
        working = SimpleNamespace(scan=lambda *args, **kwargs: report())
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "evidence"
            with patch("evaluate_audit.importlib.import_module", side_effect=[failed, working]):
                comparison = evaluate(MATRIX, components, output, source={"locked": "fixture"})
            self.assertEqual(comparison["backends"]["grype"]["status"], "failed")
            self.assertEqual(comparison["backends"]["osv"]["score"]["counts"]["affected_detected"], 1)
            self.assertEqual(json.loads((output / "grype.json").read_text())["error"]["message"], "database unavailable")
            self.assertEqual(json.loads((output / "matrix.json").read_text()), MATRIX)
            self.assertTrue((output / "comparison.txt").is_file())
            with self.assertRaises(FileExistsError):
                evaluate(MATRIX, components, output)

    def test_malformed_scanner_evidence_is_a_failed_candidate(self):
        components = [{"id": "evaluation-" + row["id"]} for row in MATRIX["cases"]]
        provider = SimpleNamespace(scan=lambda *args, **kwargs: {"backend": [], "database": {}})
        with tempfile.TemporaryDirectory() as directory, patch(
            "evaluate_audit.importlib.import_module", return_value=provider,
        ):
            comparison = evaluate(MATRIX, components, Path(directory) / "evidence", ("osv",))
        self.assertEqual(comparison["backends"]["osv"]["status"], "failed")
        self.assertIn("scanner/database evidence", comparison["backends"]["osv"]["error"]["message"])


if __name__ == "__main__":
    unittest.main()
