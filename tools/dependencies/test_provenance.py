"""Provenance finds build inputs independently of dependency declarations."""

import unittest
from unittest.mock import patch

import provenance
import recursive
from test_recursive import fixture, node, p


class ProvenanceTests(unittest.TestCase):
    def test_undeclared_transitive_provider_has_exact_identity_and_consumers(self):
        manifest, document = fixture()
        # d is shared by two build steps. Its provider is identifiable even
        # though there is no TVP deps or selector entry for either consumer.
        manifest["borrowed"] = [
            {"drv": p("d.drv"), "attribute": "known-provider", "source": p("nixpkgs")},
            {"drv": p("d.drv"), "attribute": "declared-alias", "source": None},
            {"drv": p("test-only.drv"), "attribute": "test-only", "source": p("nixpkgs")},
        ]
        manifest["roots"]["checks.fixture"] = {
            "scope": "checks", "drv": p("fixture.drv"), "outputs": ["out"],
            "status": None, "evidence": "check registration",
        }
        manifest["roots"]["variants.borrowed"] = {
            "scope": "variants", "drv": p("d.drv"), "outputs": ["out"],
            "status": None, "evidence": "variant registration",
        }
        document["derivations"][p("fixture.drv")[11:]] = node(["test-only.drv"])
        document["derivations"][p("test-only.drv")[11:]] = node()
        roots = recursive.select_roots(manifest, ["@canonical", "@tools"])
        graph = recursive.inventory(manifest, roots, document)
        self.assertNotIn(p("test-only.drv"), graph["nodes"])
        graph["excludedBrokenRoots"] = {}
        report = provenance.graph_report(graph)
        outside, = report["externalPackages"]
        self.assertEqual(outside["providers"], ["known-provider"])
        self.assertEqual(outside["consumers"], ["packages.a", "tools.alias"])
        self.assertEqual(
            [step["path"] for step in outside["witness"]["chain"]],
            [p("a.drv"), p("b.drv"), p("d.drv")],
        )
        self.assertEqual(
            {row["derivation"] for row in report["unclassifiedDerivations"]},
            {p("b.drv"), p("c.drv")},
        )

    def test_realized_report_with_no_local_outputs_skips_reference_query(self):
        data = {"runtimeRoots": {"a": p("a")}, "registry": []}
        with patch("provenance.subprocess.check_output", return_value=p("a") + "\n") as query:
            report = provenance.realized_report(data)
        self.assertEqual(report["unbuilt"], ["a"])
        self.assertEqual(report["checked"], 0)
        self.assertEqual(report["unregisteredPaths"], {})
        query.assert_called_once()


if __name__ == "__main__":
    unittest.main()
