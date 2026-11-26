"""Check opt-in advisory identity extraction without building packages."""

import json
from pathlib import Path
import subprocess
import unittest

from report import INVENTORY, diff, managed_packages
from audit import package_identity


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

    def test_family_metadata_factories_bind_tags_without_changing_override_provenance(self):
        root = Path(__file__).resolve().parents[2]
        expression = '''let
          flake = builtins.getFlake %s;
          pkgs = import flake.inputs.nixpkgs { system = "x86_64-linux"; };
          tvp = import flake.outPath { inherit pkgs; };
          ruby = tvp.canonical.ruby_3_0_6;
          override = ruby.override { version = "3.0.7"; };
        in {
          ruby = ruby.tvp.security;
          historicalRuby = tvp.canonical.ruby_2_0_0_p0.tvp.security;
          openssl = tvp.canonical.openssl_3_0_5.tvp.security;
          oldOpenSSL = tvp.canonical.openssl_1_1_1w.tvp.security;
          php = tvp.canonical.php_8_2_17.tvp.security;
          libxml2 = tvp.canonical.libxml2_2_12_4.tvp.security;
          bundler = tvp.canonical.bundler_1_17_3.tvp.security;
          overridden = { inherit (override) version; security = override.tvp.security; };
        }''' % json.dumps(str(root))
        result = subprocess.run(
            ["nix", "eval", "--impure", "--json", "--option", "allow-import-from-derivation", "false",
             "--expr", expression], capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        profiles = json.loads(result.stdout)
        for name, version, tag in (
            ("ruby", "3.0.6", "v3_0_6"), ("openssl", "3.0.5", "openssl-3.0.5"),
            ("php", "8.2.17", "php-8.2.17"), ("libxml2", "2.12.4", "v2.12.4"),
        ):
            with self.subTest(name=name):
                self.assertEqual(profiles[name]["forVersion"], version)
                self.assertEqual(profiles[name]["osv"]["version"], tag)
                self.assertEqual(package_identity(profiles[name], version)["osv"]["version"], tag)
        self.assertNotIn("osv", profiles["oldOpenSSL"])
        self.assertNotIn("osv", profiles["historicalRuby"])
        self.assertEqual(profiles["historicalRuby"]["purl"], "pkg:generic/ruby")
        self.assertEqual(profiles["bundler"]["osv"], {"ecosystem": "RubyGems", "name": "bundler"})
        overridden = profiles["overridden"]
        self.assertEqual(overridden["version"], "3.0.7")
        self.assertEqual(overridden["security"]["forVersion"], "3.0.6")
        self.assertEqual(package_identity(overridden["security"], overridden["version"]), {})


if __name__ == "__main__":
    unittest.main()
