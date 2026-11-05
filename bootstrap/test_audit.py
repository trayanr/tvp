"""Offline observer contracts. No Nix daemon or bootstrap build is needed."""
import copy
import importlib.util
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("bootstrap_audit", sys.argv.pop(1))
a = importlib.util.module_from_spec(spec)
spec.loader.exec_module(a)


def store(name):
    return "/nix/store/" + "a" * 32 + "-" + name


class AuditTests(unittest.TestCase):
    def setUp(self):
        self.seed = store("seed")
        self.seed_drv = self.seed + ".drv"
        self.stage = store("stage")
        self.stage_drv = self.stage + ".drv"
        self.provenance = {
            "seed": {"url": "https://example.invalid/seed", "narHash": "sha256-" + "A" * 43 + "="},
            "archives": [],
        }
        self.graph = {
            self.seed_drv: {
                "builder": "builtin:fetchurl",
                "env": {"url": self.provenance["seed"]["url"],
                        "outputHash": self.provenance["seed"]["narHash"], "executable": "1", "out": self.seed},
                "outputs": {"out": {"path": self.seed}}, "inputDrvs": {}, "inputSrcs": [],
            },
            self.stage_drv: {
                "builder": self.seed,
                "env": {"PATH": "", "allowSubstitutes": "", "out": self.stage},
                "outputs": {"out": {"path": self.stage}},
                "inputDrvs": {self.seed_drv: ["out"]}, "inputSrcs": [],
            },
        }

    def failures(self):
        return a.audit_graph(self.graph, {}, self.provenance, {})["failures"]

    def test_declared_seed_and_stage_pass_both_graph_protocols(self):
        self.assertEqual(self.failures(), [])
        envelope = {"version": 4, "derivations": self.graph}
        result = a.audit_graph(envelope, {}, self.provenance, {})
        self.assertEqual(result["failures"], [])
        self.assertEqual(result["nodes"][self.seed_drv]["origin"], "explicit-seed")
        self.assertEqual(result["nodes"][self.stage_drv]["origin"], "source-built-stage")

    def test_host_builder_and_undeclared_prior_stage_fail(self):
        for builder in ["/bin/sh", store("unclassified") + "/bin/sh"]:
            with self.subTest(builder=builder):
                self.graph[self.stage_drv]["builder"] = builder
                self.assertTrue(any("undeclared executable" in f for f in self.failures()))

    def test_declared_builder_cannot_escape_or_use_noncanonical_segments(self):
        for suffix in ["/../../../bin/sh", "/bin/../../../../usr/bin/env", "/./bin/sh", "//bin/sh"]:
            with self.subTest(suffix=suffix):
                self.graph[self.stage_drv]["builder"] = self.seed + suffix
                self.assertTrue(any("undeclared executable" in f for f in self.failures()))

    def test_graph_membership_does_not_replace_a_direct_input_edge(self):
        self.graph[self.stage_drv]["inputDrvs"] = {}
        self.assertTrue(any("undeclared executable" in f for f in self.failures()))

    def test_host_path_and_missing_explicit_path_fail(self):
        self.graph[self.stage_drv]["env"]["PATH"] = "/usr/bin"
        self.assertTrue(any("unclassified PATH" in f for f in self.failures()))
        del self.graph[self.stage_drv]["env"]["PATH"]
        self.assertTrue(any("missing explicit PATH" in f for f in self.failures()))

    def test_substitutable_source_stage_fails(self):
        self.graph[self.stage_drv]["env"]["allowSubstitutes"] = "1"
        self.assertTrue(any("permits substitution" in f for f in self.failures()))

    def test_wrong_hash_or_unknown_downloader_fails(self):
        for key, value in [("outputHash", "sha256-" + "B" * 43 + "="), ("url", "https://example.invalid/unknown")]:
            with self.subTest(key=key):
                graph = copy.deepcopy(self.graph)
                graph[self.seed_drv]["env"][key] = value
                result = a.audit_graph(graph, {}, self.provenance, {})
                self.assertTrue(any("unrecognized download/hash" in f for f in result["failures"]))

    def test_source_archive_must_not_be_an_executable_download(self):
        self.provenance["archives"] = [{"url": "https://example.invalid/source", "hash": self.provenance["seed"]["narHash"]}]
        self.graph[self.seed_drv]["env"]["url"] = "https://example.invalid/source"
        self.assertTrue(any("unexpected executable download" in f for f in self.failures()))

    def test_native_executable_source_data_is_rejected(self):
        self.graph[self.stage_drv]["inputSrcs"] = [store("source.c")]
        with patch.object(Path, "is_file", return_value=True), patch.object(Path, "is_dir", return_value=False):
            with patch.object(Path, "read_bytes", return_value=b"int main(void) { return 0; }"):
                self.assertEqual(self.failures(), [])
            for magic in [b"\x7fELF", b"MZ"]:
                with self.subTest(magic=magic), patch.object(Path, "read_bytes", return_value=magic):
                    self.assertTrue(any("native executable in source" in f for f in self.failures()))


if __name__ == "__main__":
    unittest.main(verbosity=2)
