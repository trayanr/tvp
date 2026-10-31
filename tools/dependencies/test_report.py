"""Reporting contracts exercised independently of the Nix selector tests."""

import copy
import json
import unittest
from unittest.mock import patch

import report


def edge(consumer="ruby_3_0_1", *, kind="major", selector="openssl_1", version="1.1.1w"):
    return {
        "consumer": consumer, "consumerVersion": consumer.removeprefix("ruby_"),
        "family": "ruby", "definition": "3.0.0", "scope": "ordinary", "dependency": "openssl",
        "selection": {"namespace": "packages", "selector": selector, "kind": kind},
        "resolved": {"tvp": True, "family": "openssl", "version": version,
                     "drv": "/nix/store/openssl.drv", "out": "/nix/store/openssl", "output": "out"},
        "reason": None,
    }


class ReportingTests(unittest.TestCase):
    def test_shared_definition_choices_and_resolved_releases_are_distinct_measures(self):
        rows = [edge("ruby_3_0_1"), edge("ruby_3_0_2"), edge("ruby_3_0_3")]
        rows.append(edge("ruby_3_1_0", kind="minor", selector="openssl_1_1"))
        rows[-1]["definition"] = "3.1.0"
        result = report.counts(rows)
        self.assertEqual(result["expandedEdges"], 4)
        self.assertEqual(result["distinctDeclarationChoices"], 2)
        self.assertEqual(result["requestedSelectors"], 2)
        self.assertEqual(result["resolvedReleases"], 1)
        self.assertEqual(result["resolvedProducers"], 1)
        self.assertEqual(result["byKind"]["major"], 3)
        self.assertEqual(result["declarationsByKind"]["major"], 1)
        self.assertEqual(sum(result["byKind"].values()), 4)
        self.assertEqual(sum(result["byScope"].values()), 4)
        self.assertEqual(set(result["byKind"]), set(report.KINDS))
        self.assertEqual(result["byKind"]["exact"], 0)

    def test_namespace_and_requested_kind_never_inferred_from_resolved_version(self):
        alias = edge(kind="finer", selector="openssl_1_1_1", version="1.1.1")
        exact = copy.deepcopy(alias)
        exact["consumer"] = "ruby_3_1_0"
        exact["selection"].update(namespace="canonical", kind="exact")
        summary = report.counts([alias, exact])
        self.assertEqual(summary["requestedSelectors"], 2)
        self.assertEqual(summary["resolvedReleases"], 1)
        self.assertEqual(summary["byKind"]["finer"], 1)
        self.assertEqual(summary["byKind"]["exact"], 1)

    def test_missing_and_ambiguous_intent_are_unknown_and_foreign_is_explicit(self):
        unknown = edge()
        unknown["selection"] = None
        ambiguous = copy.deepcopy(unknown)
        ambiguous["consumer"] = "ruby_3_0_2"
        ambiguous["selection"] = [edge()["selection"], edge()["selection"]]
        foreign = copy.deepcopy(unknown)
        foreign["consumer"] = "ruby_3_0_3"
        foreign["resolved"]["tvp"] = False
        inventory = {"schema": 1, "edges": [unknown, ambiguous, foreign], "support": []}
        result = report.summarize(inventory)
        self.assertEqual(result["all"]["byKind"]["unknown"], 2)
        self.assertEqual(result["all"]["byKind"]["foreign"], 1)
        self.assertEqual(len(result["unknownEdges"]), 2)

    def test_duplicate_edges_are_retained_and_diagnosed(self):
        inventory = {"schema": 1, "edges": [edge(), edge()], "support": []}
        result = report.summarize(inventory)
        self.assertEqual(result["all"]["expandedEdges"], 2)
        self.assertEqual(result["all"]["distinctDeclarationChoices"], 1)
        self.assertEqual(result["duplicateEdges"][0]["occurrences"], 2)
        with self.assertRaisesRegex(ValueError, "duplicate dependency edge"):
            report.compare(inventory, inventory)

    def test_output_projection_is_a_distinct_declaration_choice(self):
        first = edge()
        second = edge("ruby_3_0_2")
        second["resolved"]["output"] = "dev"
        result = report.counts([first, second])
        self.assertEqual(result["distinctDeclarationChoices"], 2)
        self.assertEqual(result["resolvedReleases"], 1)
        self.assertEqual(result["resolvedProducers"], 1)

    def test_compare_separates_selector_changes_releases_and_rebuilds(self):
        rows = [edge("ruby_3_0_1"), edge("ruby_3_0_2"), edge("ruby_3_0_3")]
        before = {"schema": 1, "edges": rows}
        after = copy.deepcopy(before)
        after["edges"][0]["selection"]["selector"] = "openssl"
        after["edges"][1]["resolved"]["drv"] = "/nix/store/rebuilt-openssl.drv"
        after["edges"][2]["resolved"].update(version="3.0.1", drv="/nix/store/new-openssl.drv")
        result = report.compare(before, after)
        self.assertEqual(result["changedEdges"], 3)
        self.assertEqual(result["changedResolvedIdentityEdges"], 2)
        self.assertEqual(result["changedResolvedReleaseEdges"], 1)
        self.assertEqual(result["changes"][0]["before"]["resolved"]["version"], "1.1.1w")

    def test_scope_reclassification_is_not_a_resolved_release_change(self):
        original = edge()
        original["ownerScope"] = "ordinary"
        changed = copy.deepcopy(original)
        changed["scope"] = "construction"
        changed["reason"] = "Explicit bootstrap stage"
        result = report.compare({"edges": [original]}, {"edges": [changed]})
        self.assertEqual(result["changedEdges"], 1)
        self.assertEqual(result["changedResolvedReleaseEdges"], 0)
        self.assertEqual(result["changedResolvedIdentityEdges"], 0)

    @patch("report.subprocess.check_output")
    def test_flake_is_resolved_once_then_evaluated_as_immutable_source(self, run):
        metadata = {"path": "/nix/store/frozen-source", "locked": {"rev": "abc"}, "revision": "abc"}
        run.side_effect = [json.dumps(metadata), json.dumps({"schema": 1, "edges": [], "support": []})]
        result = report.evaluate("git+file:///work/tree?rev=abc", "aarch64-linux")
        self.assertEqual(run.call_count, 2)
        evaluation = run.call_args_list[1].args[0]
        self.assertIn("path:/nix/store/frozen-source#legacyPackages.aarch64-linux.dependencyInventory", evaluation)
        self.assertIn("--offline", evaluation)
        self.assertIn("--no-write-lock-file", evaluation)
        self.assertEqual(result["snapshot"]["revision"], "abc")
        self.assertEqual(result["snapshot"]["system"], "aarch64-linux")

    @patch("report.subprocess.check_output")
    def test_mutable_metadata_source_is_rejected(self, run):
        run.return_value = json.dumps({"path": "/work/tree"})
        with self.assertRaisesRegex(ValueError, "immutable store source"):
            report.evaluate(".", "x86_64-linux")
        self.assertEqual(run.call_count, 1)


if __name__ == "__main__":
    unittest.main()
