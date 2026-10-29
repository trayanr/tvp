import importlib.util
import sys
import unittest

spec = importlib.util.spec_from_file_location("runtime", sys.argv.pop(1))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class RuntimeContract(unittest.TestCase):
    def test_new_foreign_transitive_dependency_fails(self):
        result = module.audit({"app": "app"}, {"app": ["library"], "library": ["foreign"], "foreign": []}, {"app", "library"}, {})
        self.assertEqual(result["unexpected"], {"app": ["foreign"]})

    def test_existing_debt_is_scoped_to_its_package(self):
        graph = {"old": ["foreign"], "new": ["foreign"], "foreign": []}
        result = module.audit({"old": "old", "new": "new"}, graph, {"old", "new"}, {"old": {"paths": ["foreign"]}})
        self.assertEqual(result["unexpected"], {"new": ["foreign"]})

    def test_cleared_debt_and_removed_roots_require_baseline_update(self):
        baseline = {"app": {"paths": ["foreign"]}, "removed": {"paths": ["old"]}}
        result = module.audit({"app": "app"}, {"app": []}, {"app"}, baseline)
        self.assertEqual(set(result["stale"]), {"app", "removed"})
        self.assertEqual(result["clean"], ["app"])

    def test_self_and_shared_references_terminate(self):
        graph = {"app": ["app", "shared"], "shared": ["app"]}
        result = module.audit({"app": "app"}, graph, set(graph), {})
        self.assertEqual(result["clean"], ["app"])

    def test_missing_reference_graph_is_an_error(self):
        with self.assertRaises(ValueError):
            module.audit({"app": "app"}, {"app": ["missing"]}, {"app"}, {})


if __name__ == "__main__":
    unittest.main()
