"""Exercise the consumer CLI against two local flake revisions without builds."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


CLI = Path(__file__).with_name("cli.py").resolve()
SYSTEM = "x86_64-linux"
UPSTREAM = """{
  outputs = { self }:
    let
      system = "x86_64-linux";
      mkPackage = namespace: selector: kind: pname: version: recipe:
        (builtins.derivation {
          inherit system pname version recipe;
          name = "${pname}-${version}";
          builder = "/bin/false";
        }) // {
          tvp = { status.level = "ok"; };
          __tvpSelection = {
            inherit namespace selector kind pname version;
            canonical = "${pname}_${builtins.replaceStrings ["."] ["_"] version}";
          };
        };
      php = mkPackage "packages" "php_8_2" "minor" "php" "@PHP@" "same";
      ruby = mkPackage "canonical" "ruby_2_7_0" "exact" "ruby" "2.7.0" "@RECIPE@";
      redis = (builtins.derivation {
        inherit system php;
        name = "redis-@REDIS@-for-${php.version}";
        pname = "php-redis";
        version = "@REDIS@";
        builder = "/bin/false";
      }) // {
        extensionName = "redis";
        modulePath = "lib/php/extensions/redis.so";
        loader = "extension";
      };
      phpWithExtensions = (builtins.derivation {
        inherit system php redis;
        name = "php-with-extensions-${php.version}";
        pname = "php-with-extensions";
        version = php.version;
        builder = "/bin/false";
      }) // {
        tvp.kind = "php-runtime";
        __tvpSelection.kind = "composition";
        unwrapped = php;
        enabledExtensions = [ redis ];
      };
    in {
      packages.${system} = {
        php_8_2 = php;
        inherit phpWithExtensions;
      };
      legacyPackages.${system}.canonical.ruby_2_7_0 = ruby;
    };
}
"""
PROJECT = """{
  inputs.tvp.url = @URL@;
  outputs = { self, tvp }:
    let
      system = "x86_64-linux";
      unrelated = builtins.derivation {
        inherit system;
        name = "unrelated-1.0.0";
        version = "1.0.0";
        builder = "/bin/false";
      };
    in {
      devShells.${system}.default = builtins.derivation {
        inherit system;
        name = "consumer-shell";
        builder = "/bin/false";
        buildInputs = [ tvp.packages.${system}.phpWithExtensions unrelated ];
        nativeBuildInputs = [ tvp.legacyPackages.${system}.canonical.ruby_2_7_0 ];
      };
    };
}
"""


class ConsumerIntegrationTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="tvp-consumer-test-")
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.upstream = self.root / "upstream"
        self.project = self.root / "project"
        self.upstream.mkdir()
        self.project.mkdir()
        self.env = os.environ.copy()
        self.env["NIX_CONFIG"] = (
            self.env.get("NIX_CONFIG", "") + "\nextra-experimental-features = nix-command flakes\n"
        )
        self.command("git", "init", "--quiet", cwd=self.upstream)
        self.commit_upstream("8.2.1", "6.2.0", "original")
        url = "git+" + self.upstream.as_uri()
        (self.project / "flake.nix").write_text(PROJECT.replace("@URL@", json.dumps(url)))
        self.command("nix", "flake", "lock", cwd=self.project)
        self.lock = self.project / "flake.lock"
        self.original_lock = self.lock.read_bytes()

    def command(self, *args, cwd):
        result = subprocess.run(args, cwd=cwd, env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, f"{args}\n{result.stdout}{result.stderr}")
        return result.stdout

    def commit_upstream(self, php_version, redis_version, recipe):
        source = (UPSTREAM.replace("@PHP@", php_version)
                  .replace("@REDIS@", redis_version).replace("@RECIPE@", recipe))
        (self.upstream / "flake.nix").write_text(source)
        self.command("git", "add", "flake.nix", cwd=self.upstream)
        self.command(
            "git", "-c", "user.name=TVP test", "-c", "user.email=tvp@example.invalid",
            "-c", "commit.gpgsign=false", "commit", "--quiet", "-m", recipe,
            cwd=self.upstream,
        )

    def tvp(self, command, *args):
        return json.loads(self.command(
            sys.executable, "-B", str(CLI), command, *args, "--flake", str(self.project),
            "--attr", f"devShells.{SYSTEM}.default", "--json", cwd=self.root,
        ))

    def test_preview_matches_lockfile_diff_and_preserves_the_worktree(self):
        inventory = self.tvp("used")
        packages = {row["pname"]: (row["selector"], row["version"]) for row in inventory["packages"]}
        self.assertEqual(packages, {
            "php-with-extensions": (None, "8.2.1"),
            "php": ("php_8_2", "8.2.1"),
            "php-redis": (None, "6.2.0"),
            "ruby": ("ruby_2_7_0", "2.7.0"),
        })
        self.assertEqual(self.tvp("update", "--preview")["changes"], [])
        self.assertEqual(self.lock.read_bytes(), self.original_lock)

        self.commit_upstream("8.2.2", "6.2.1", "revised")
        preview = self.tvp("update", "--preview")
        self.assertEqual(self.lock.read_bytes(), self.original_lock)

        before = self.root / "before.lock"
        before.write_bytes(self.original_lock)
        self.command("nix", "flake", "update", "tvp", cwd=self.project)
        self.assertNotEqual(self.lock.read_bytes(), self.original_lock)
        comparison = self.tvp("diff", str(before), str(self.lock))
        self.assertEqual(preview, comparison)
        self.assertEqual(comparison, self.tvp("diff", str(before)))

        changes = {row["after"]["pname"]: row for row in comparison["changes"]}
        for package, old, new in (("php", "8.2.1", "8.2.2"), ("php-redis", "6.2.0", "6.2.1")):
            with self.subTest(package=package):
                self.assertEqual(changes[package]["before"]["version"], old)
                self.assertEqual(changes[package]["after"]["version"], new)
                self.assertTrue(changes[package]["versionChanged"])
        self.assertEqual(changes["ruby"]["after"]["version"], "2.7.0")
        self.assertFalse(changes["ruby"]["versionChanged"])
        self.assertTrue(changes["ruby"]["derivationChanged"])


if __name__ == "__main__":
    unittest.main()
