"""Native v4 protocol and graph semantics, independent of installed outputs."""

import copy
import io
import json
import unittest
from contextlib import redirect_stderr
from unittest.mock import patch

import recursive as r
import report


def p(name):
    return "/nix/store/" + "0" * 32 + "-" + name


def node(inputs=(), srcs=(), outputs=None):
    return {"builder": p("bash") + "/bin/bash", "system": "x86_64-linux",
            "outputs": outputs or {"out": {"path": p("result")[11:]}},
            "inputs": {"drvs": {p(n)[11:]: {"outputs": ["out"], "dynamicOutputs": {}} for n in inputs},
                       "srcs": [p(s)[11:] for s in srcs]}}


def fixture():
    nodes = {p("a.drv")[11:]: node(["b.drv", "c.drv"], ["archive", "metadata.drv"]),
             p("b.drv")[11:]: node(["d.drv"]), p("c.drv")[11:]: node(["d.drv"]),
             p("d.drv")[11:]: node()}
    roots = {name: {"scope": scope, "drv": p(drv), "outputs": ["out"], "status": None, "evidence": "test registration"}
             for name, scope, drv in [("packages.a", "canonical", "a.drv"), ("tools.alias", "tools", "a.drv")]}
    manifest = {"schema": 1, "roots": roots, "groups": {"canonical": ["packages.a"], "tools": ["tools.alias"]},
                "defaultGroup": "canonical", "outputRegistrations": [], "borrowed": []}
    return manifest, {"version": 4, "derivations": nodes}


class RecursiveTests(unittest.TestCase):
    def test_diamond_aliases_and_sources_do_not_create_extra_build_nodes(self):
        manifest, doc = fixture()
        roots = r.select_roots(manifest, ["@canonical", "@tools"])
        result = r.inventory(manifest, roots, doc)
        self.assertEqual(result["state"], "complete")
        self.assertEqual(result["summary"]["derivations"], 4)
        self.assertEqual(result["summary"]["derivationEdges"], 4)
        self.assertEqual(result["summary"]["sourceInputs"], 2)
        self.assertEqual(len(result["roots"]), 2)
        self.assertNotIn(p("metadata.drv"), result["nodes"])
        witness = r.explain(result, p("d.drv"))
        self.assertEqual(witness["root"], "packages.a")
        self.assertEqual([s["path"] for s in witness["chain"]], [p("a.drv"), p("b.drv"), p("d.drv")])
        self.assertEqual(r.explain(result, p("metadata.drv"))["chain"][-1]["edge"], "input-source")
        with self.assertRaisesRegex(ValueError, "not reachable"):
            r.explain(result, p("unrelated"))

    def test_drv_as_source_does_not_suppress_later_build_edge(self):
        manifest, doc = fixture()
        doc["derivations"][p("a.drv")[11:]]["inputs"]["srcs"].append(p("d.drv"))
        doc["derivations"][p("d.drv")[11:]] = node(["e.drv"])
        doc["derivations"][p("e.drv")[11:]] = node()
        result = r.inventory(manifest, r.select_roots(manifest, None), doc)
        self.assertEqual(result["summary"]["derivations"], 5)
        self.assertEqual(r.explain(result, p("d.drv"))["chain"][-1]["edge"], "input-derivation")
        # An unrelated returned recipe appearing only as a source stays a source.
        doc["derivations"][p("metadata.drv")[11:]] = node()
        result = r.inventory(manifest, r.select_roots(manifest, None), doc)
        self.assertNotIn(p("metadata.drv"), result["nodes"])

    def test_order_and_default_group_and_label_validation(self):
        manifest, doc = fixture()
        roots = r.select_roots(manifest, None)
        first = r.inventory(manifest, roots, doc)
        doc["derivations"] = dict(reversed(list(doc["derivations"].items())))
        self.assertEqual(first, r.inventory(manifest, roots, doc))
        self.assertEqual(list(roots), ["packages.a"])
        for label in ["packages.nope", "@invalid", "builtins.abort"]:
            with self.assertRaises(ValueError):
                r.select_roots(manifest, [label])

    def test_multiple_selected_and_deferred_outputs_and_dynamic_information(self):
        manifest, doc = fixture()
        raw = doc["derivations"]
        raw[p("a.drv")[11:]]["inputs"]["drvs"][p("b.drv")[11:]] = {
            "outputs": ["out", "dev"], "dynamicOutputs": {"out": {"outputs": ["out"], "dynamicOutputs": {}}}}
        raw[p("b.drv")[11:]]["outputs"]["dev"] = {"hashAlgo": "sha256", "method": "nar"}
        result = r.inventory(manifest, r.select_roots(manifest, None), doc)
        self.assertEqual(result["state"], "partial")
        self.assertEqual(result["nodes"][p("b.drv")]["outputs"]["dev"]["pathState"], "unresolved")
        self.assertEqual(result["summary"]["dynamicEdges"], 1)
        self.assertEqual(result["nodes"][p("a.drv")]["inputDrvs"][p("b.drv")]["outputs"], ["dev", "out"])

    def test_evidence_is_not_name_or_registered_deriver_canonicalization(self):
        manifest, doc = fixture()
        doc["derivations"][p("b.drv")[11:]]["outputs"] = {"out": {"path": p("substrate")}}
        manifest["outputRegistrations"] = [{"path": p("substrate"), "source": "substrate", "kind": "base"}]
        manifest["borrowed"] = [{"drv": p("c.drv"), "attribute": "shellcheck-minimal", "source": p("pinned-source")}]
        result = r.inventory(manifest, r.select_roots(manifest, None), doc)
        self.assertEqual({k: v["classification"] for k, v in result["nodes"].items()}, {
            p("a.drv"): "registered-definition", p("b.drv"): "registered-substrate-output",
            p("c.drv"): "explicit-borrowed", p("d.drv"): "unclassified"})
        # Equal output paths never collapse intended recipes; no path-info/deriver lookup.
        self.assertEqual(result["summary"]["derivations"], 4)

    def test_malformed_protocol_fields_and_unsafe_paths(self):
        _, doc = fixture()
        mutations = [lambda x: x.update(version=5), lambda x: x.update(derivations=[]),
                     lambda x: x["derivations"].update({"../../bad.drv": node()}),
                     lambda x: x["derivations"][p("a.drv")[11:]]["inputs"].update(srcs="not-list"),
                     lambda x: x["derivations"][p("a.drv")[11:]].update(system=None),
                     lambda x: x["derivations"][p("a.drv")[11:]]["inputs"]["drvs"].update({p("bad.drv"): {"outputs": []}})]
        for mutation in mutations:
            bad = copy.deepcopy(doc)
            mutation(bad)
            with self.assertRaises(ValueError):
                r.normalize(bad)

    def test_missing_nodes_roots_broken_cycles_and_output_names_are_partial(self):
        manifest, doc = fixture()
        del doc["derivations"][p("d.drv")[11:]]
        roots = r.select_roots(manifest, None)
        result = r.inventory(manifest, roots, doc)
        self.assertEqual(result["state"], "partial")
        self.assertTrue(any(d["kind"] == "missing-node" for d in result["diagnostics"]))
        result = r.inventory(manifest, roots, {"version": 4, "derivations": {}})
        self.assertEqual(result["diagnostics"][0]["kind"], "missing-root")
        manifest, doc = fixture()
        doc["derivations"][p("d.drv")[11:]] = node(["a.drv"])
        result = r.inventory(manifest, r.select_roots(manifest, None), doc)
        self.assertTrue(any(d["kind"] == "cycle" for d in result["diagnostics"]))
        manifest["roots"]["packages.a"].update(drv=None, status={"level": "broken", "reason": "unsupported"})
        result = r.inventory(manifest, r.select_roots(manifest, ["packages.a"]), doc)
        self.assertEqual(result["diagnostics"][0]["kind"], "broken-root")
        manifest, doc = fixture()
        manifest["roots"]["packages.a"]["outputs"] = ["absent"]
        result = r.inventory(manifest, r.select_roots(manifest, None), doc)
        self.assertTrue(any(d["kind"] == "missing-root-output" for d in result["diagnostics"]))

    def test_flags_fail_before_evaluation(self):
        for args in [["--root", "x"], ["--recursive", "--compare", "x"], ["--recursive", "--kind", "exact"],
                     ["--recursive", "--scope", "ordinary"], ["--recursive", "--exceptions"],
                     ["--recursive", "--family", "x"], ["--recursive", "--list-roots", "--why", "x"]]:
            with patch("report.evaluate") as evaluate, redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                report.main(args)
            evaluate.assert_not_called()

    def test_native_query_errors_are_structured_and_commands_are_metadata_only(self):
        manifest, _ = fixture()
        snapshot = {"flake": "path:" + p("source"), "system": "x86_64-linux"}
        with patch("recursive.subprocess.check_output", return_value=json.dumps(manifest)) as evaluation, \
                patch("os.path.isfile", return_value=True), patch("recursive.subprocess.run") as query:
            query.return_value.returncode = 1
            query.return_value.stderr = "missing recipe"
            result = r.collect(snapshot, None)
            self.assertEqual(result["state"], "partial")
            self.assertTrue(any(d["kind"] == "native-query-failed" for d in result["diagnostics"]))
            self.assertIn("--offline", evaluation.call_args.args[0])
            command = query.call_args.args[0]
            self.assertEqual(command[:3], ["nix", "derivation", "show"])
            self.assertIn("--stdin", command)
            self.assertIn("--recursive", command)
            self.assertIn("allow-import-from-derivation", command)
            self.assertEqual(query.call_count, 1)
            self.assertEqual(query.call_args.kwargs["input"], p("a.drv") + "\n")
            query.return_value.returncode = 0
            query.return_value.stdout = "{invalid JSON"
            result = r.collect(snapshot, None)
            self.assertEqual(result["state"], "partial")
            self.assertTrue(any(d["kind"] == "invalid-native-metadata" for d in result["diagnostics"]))


if __name__ == "__main__":
    unittest.main()
