"""The qualified regression gate must reject crashes and changed failures."""
import ast
import errno
from pathlib import Path
import unittest

module = ast.parse(Path(__file__).with_name("source-python-checks.py").read_text())
function = next(n for n in module.body if isinstance(n, ast.FunctionDef) and n.name == "validate_regressions")
namespace = {"errno": errno}
exec(compile(ast.Module(body=[function], type_ignores=[]), "regression-gate", "exec"), namespace)
validate = namespace["validate_regressions"]

class RegressionGate(unittest.TestCase):
    def setUp(self):
        self.controls = {"mode": dict(requested=0o7777, actual=0o644, errno=errno.EPERM)}
        self.row = dict(status=1, tests=608, failures=1, errors=0, skips=8,
            failureDetails=[dict(id="test.test_tarfile.TestExtractionFilters.test_modes",
                traceback="AssertionError: '?rw-r--r--' != '?rwsrwsrwt'\n")], errorDetails=[])

    def test_measured_restriction(self):
        validate({"test_tarfile": self.row}, self.controls)

    def test_crash_without_summary(self):
        with self.assertRaises(AssertionError):
            validate({"test_tarfile": dict(status=1)}, self.controls)

    def test_signal(self):
        self.row["status"] = -15
        with self.assertRaises(AssertionError):
            validate({"test_tarfile": self.row}, self.controls)

    def test_changed_failure(self):
        self.row["failureDetails"][0]["traceback"] = "AssertionError: unrelated regression"
        with self.assertRaises(AssertionError):
            validate({"test_tarfile": self.row}, self.controls)

    def test_unproven_restriction(self):
        self.controls["mode"]["errno"] = 0
        with self.assertRaises(AssertionError):
            validate({"test_tarfile": self.row}, self.controls)

    def test_inconsistent_result(self):
        self.row["status"] = 0
        with self.assertRaises(AssertionError):
            validate({"test_tarfile": self.row}, self.controls)

if __name__ == "__main__":
    unittest.main()
