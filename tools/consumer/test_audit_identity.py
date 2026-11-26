"""Check opt-in advisory identity extraction without building packages."""

import json
import subprocess
import unittest

from report import INVENTORY, diff, managed_packages


PACKAGE = r"""
(builtins.derivation {
  name = "synthetic-package-1.0";
  pname = "synthetic-package";
  version = "1.0";
  system = "x86_64-linux";
  builder = "/bin/false";
}) // {
  __tvpSelection = { namespace = "packages"; selector = "synthetic"; kind = "exact"; };
  @METADATA@
}
"""


class AuditIdentityTests(unittest.TestCase):
    def observe(self, metadata, *, security):
        package = PACKAGE.replace("@METADATA@", metadata)
        expression = f"({INVENTORY}) {'true' if security else 'false'} ({package})"
        result = subprocess.run(
            ["nix", "eval", "--json", "--expr", expression],
            check=True, capture_output=True, text=True,
        )
        return managed_packages(json.loads(result.stdout))

    def test_regular_inventory_does_not_evaluate_security_metadata(self):
        observed = self.observe('tvp.security = throw "audit metadata was forced";', security=False)
        self.assertEqual(len(observed), 1)
        self.assertNotIn("security", observed[0])

    def test_audit_extracts_declared_profile_without_changing_package_identity(self):
        metadata = '''tvp.security = {
          schema = 1;
          purl = "pkg:gem/example";
          osv = { ecosystem = "RubyGems"; name = "example"; };
        };'''
        ordinary = self.observe(metadata, security=False)[0]
        audit = self.observe(metadata, security=True)[0]
        self.assertEqual(audit.pop("security"), {
            "schema": 1,
            "purl": "pkg:gem/example",
            "osv": {"ecosystem": "RubyGems", "name": "example"},
        })
        self.assertEqual(audit, ordinary)

    def test_missing_profile_is_explicitly_unmapped(self):
        observed = self.observe("", security=True)
        self.assertIsNone(observed[0]["security"])

    def test_security_profile_changes_are_not_package_updates(self):
        before_packages = self.observe('tvp.security = { schema = 1; purl = "pkg:generic/old"; };', security=True)
        after_packages = self.observe('tvp.security = { schema = 1; purl = "pkg:generic/new"; };', security=True)
        before = {"attribute": "package", "input": {}, "packages": before_packages}
        after = {"attribute": "package", "input": {}, "packages": after_packages}
        self.assertEqual(diff(before, after)["changes"], [])


if __name__ == "__main__":
    unittest.main()
