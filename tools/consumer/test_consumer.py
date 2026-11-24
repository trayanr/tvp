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
      postgresql = mkPackage "packages" "postgresql_16" "major" "postgresql" "@NATIVE@" "same";
      mkGem = gemName: version: recipe:
        (builtins.derivation {
          inherit system ruby gemName version recipe;
          nativeInputs = if gemName == "tvp-native" then [ postgresql ] else [ ];
          name = "ruby-${gemName}-${version}";
          pname = "ruby-${gemName}";
          builder = "/bin/false";
        }) // {
          inherit gemName ruby;
          nativeProviders = if gemName == "tvp-native" then { inherit postgresql; } else { };
          __tvpSelection.kind = "custom";
        };
      pure = mkGem "tvp-pure" "@GEM@" "same";
      native = mkGem "tvp-native" "1.0.0" "@RECIPE@";
      boundBundler = (builtins.derivation {
        inherit system ruby;
        name = "bundler-@MANAGER@";
        pname = "bundler";
        version = "@MANAGER@";
        builder = "/bin/false";
      }) // {
        inherit ruby;
        __tvpSelection.kind = "override";
      };
      rubyBundle = (builtins.derivation {
        inherit system ruby pure native boundBundler;
        name = "synthetic-bundle-${ruby.version}";
        pname = "synthetic-bundle";
        version = ruby.version;
        builder = "/bin/false";
      }) // {
        inherit ruby;
        bundler = boundBundler;
        gems = { tvp-pure = pure; tvp-native = native; };
        tvp.kind = "ruby-bundle";
        __tvpSelection.kind = "composition";
      };
      rubyApplication = (builtins.derivation {
        inherit system rubyBundle;
        name = "synthetic-application-1.0.0";
        pname = "synthetic-application";
        version = "1.0.0";
        builder = "/bin/false";
      }) // {
        bundle = rubyBundle;
        tvp.kind = "ruby-application";
        __tvpSelection.kind = "composition";
      };
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
        inherit phpWithExtensions rubyBundle rubyApplication;
        bundler = mkPackage "packages" "bundler" "latest" "bundler" "4.0.0" "unbound";
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
      packages.${system} = {
        inherit (tvp.packages.${system}) rubyBundle rubyApplication;
      };
      devShells.${system} = {
        ruby = builtins.derivation {
          inherit system;
          name = "ruby-consumer-shell";
          builder = "/bin/false";
          buildInputs = [ tvp.packages.${system}.rubyBundle ];
        };
        default = builtins.derivation {
          inherit system;
          name = "consumer-shell";
          builder = "/bin/false";
          buildInputs = [ tvp.packages.${system}.phpWithExtensions unrelated ];
          nativeBuildInputs = [ tvp.legacyPackages.${system}.canonical.ruby_2_7_0 ];
        };
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

    def commit_upstream(
        self, php_version, redis_version, recipe,
        gem_version="1.0.0", manager_version="1.17.3",
        native_version="16.16",
    ):
        source = (UPSTREAM.replace("@PHP@", php_version)
                  .replace("@REDIS@", redis_version).replace("@RECIPE@", recipe)
                  .replace("@GEM@", gem_version).replace("@MANAGER@", manager_version)
                  .replace("@NATIVE@", native_version))
        (self.upstream / "flake.nix").write_text(source)
        self.command("git", "add", "flake.nix", cwd=self.upstream)
        self.command(
            "git", "-c", "user.name=TVP test", "-c", "user.email=tvp@example.invalid",
            "-c", "commit.gpgsign=false", "commit", "--quiet", "-m", recipe,
            cwd=self.upstream,
        )

    def tvp(self, command, *args, attribute=None):
        return json.loads(self.command(
            sys.executable, "-B", str(CLI), command, *args, "--flake", str(self.project),
            "--attr", attribute or f"devShells.{SYSTEM}.default", "--json", cwd=self.root,
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

    def test_ruby_bundle_reports_bound_components_and_gem_changes(self):
        attribute = f"packages.{SYSTEM}.rubyBundle"
        inventory = self.tvp("used", attribute=attribute)
        components = {
            row["role"]: row for row in inventory["packages"]
            if row["role"] not in ("ruby-gem", "ruby-native-package")
        }
        self.assertEqual(set(components), {"ruby-bundle", "ruby-engine", "ruby-manager"})
        self.assertEqual(components["ruby-engine"]["version"], "2.7.0")
        self.assertEqual(components["ruby-manager"]["version"], "1.17.3")
        self.assertEqual(components["ruby-manager"]["kind"], "override")
        gems = {row["gemName"]: row for row in inventory["packages"] if row["role"] == "ruby-gem"}
        self.assertEqual(set(gems), {"tvp-pure", "tvp-native"})
        self.assertEqual(gems["tvp-pure"]["version"], "1.0.0")
        native_packages = [row for row in inventory["packages"] if row["role"] == "ruby-native-package"]
        self.assertEqual(len(native_packages), 1)
        self.assertEqual(native_packages[0]["providerName"], "postgresql")
        self.assertEqual(native_packages[0]["version"], "16.16")
        shell_inventory = self.tvp("used", attribute=f"devShells.{SYSTEM}.ruby")
        self.assertEqual(len(shell_inventory["packages"]), len(inventory["packages"]))
        self.assertTrue(all(
            row["location"].startswith("buildInputs[0]")
            for row in shell_inventory["packages"]
        ))
        application_attribute = f"packages.{SYSTEM}.rubyApplication"
        application_inventory = self.tvp("used", attribute=application_attribute)
        self.assertEqual(len(application_inventory["packages"]), len(inventory["packages"]) + 1)
        application = application_inventory["packages"][0]
        self.assertEqual(application["role"], "ruby-application")
        self.assertEqual(application["version"], "1.0.0")
        self.assertEqual(
            {row["gemName"] for row in application_inventory["packages"] if row["role"] == "ruby-gem"},
            set(gems),
        )

        self.commit_upstream(
            "8.2.1", "6.2.0", "revised",
            gem_version="1.1.0", manager_version="2.1.2",
            native_version="16.17",
        )
        comparison = self.tvp("update", "--preview", attribute=attribute)
        self.assertEqual(self.lock.read_bytes(), self.original_lock)
        self.assertEqual({entry["change"] for entry in comparison["changes"]}, {"changed"})
        changes = {
            entry["after"]["role"]: entry for entry in comparison["changes"]
            if entry["after"]["role"] != "ruby-gem"
        }
        self.assertTrue(changes["ruby-manager"]["versionChanged"])
        self.assertEqual(changes["ruby-manager"]["after"]["version"], "2.1.2")
        self.assertFalse(changes["ruby-engine"]["versionChanged"])
        self.assertTrue(changes["ruby-native-package"]["versionChanged"])
        self.assertEqual(changes["ruby-native-package"]["after"]["version"], "16.17")
        gem_changes = {
            entry["after"]["gemName"]: entry for entry in comparison["changes"]
            if entry["after"]["role"] == "ruby-gem"
        }
        self.assertTrue(gem_changes["tvp-pure"]["versionChanged"])
        self.assertEqual(gem_changes["tvp-pure"]["before"]["version"], "1.0.0")
        self.assertEqual(gem_changes["tvp-pure"]["after"]["version"], "1.1.0")
        self.assertFalse(gem_changes["tvp-native"]["versionChanged"])
        self.assertTrue(gem_changes["tvp-native"]["derivationChanged"])
        application_preview = self.tvp("update", "--preview", attribute=application_attribute)
        application_change = next(
            row for row in application_preview["changes"] if row["after"]["role"] == "ruby-application"
        )
        self.assertFalse(application_change["versionChanged"])
        self.assertTrue(application_change["derivationChanged"])
        self.assertEqual(
            {row["after"]["gemName"] for row in application_preview["changes"]
             if row["after"]["role"] == "ruby-gem"},
            set(gem_changes),
        )
        self.assertEqual(self.lock.read_bytes(), self.original_lock)


if __name__ == "__main__":
    unittest.main()
