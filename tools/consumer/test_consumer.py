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
      externalLibrary = builtins.derivation {
        inherit system;
        name = "external-library-1.0.0";
        version = "1.0.0";
        builder = "/bin/false";
      };
      mkGem = gemName: version: recipe:
        (builtins.derivation {
          inherit system ruby gemName version recipe;
          nativeInputs = if gemName != "tvp-pure" then [ postgresql externalLibrary ] else [ ];
          name = "ruby-${gemName}-${version}";
          pname = "ruby-${gemName}";
          builder = "/bin/false";
        }) // {
          inherit gemName ruby;
          nativeProviders = if gemName != "tvp-pure" then { inherit postgresql externalLibrary; } else { };
          tvp.kind = "ruby-gem";
          __tvpSelection.kind = "custom";
        };
      pure = mkGem "tvp-pure" "@GEM@" "same";
      native = mkGem "tvp-native" "1.0.0" "@RECIPE@";
      other = mkGem "tvp-other" "1.0.0" "same";
      postgresqlAlias = postgresql // {
        __tvpSelection = postgresql.__tvpSelection // { namespace = "canonical"; selector = "postgresql_exact"; kind = "exact"; };
      };
      postgresqlVariant = mkPackage "packages" "postgresql_16" "override" "postgresql" "@NATIVE@" "alternate";
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
        inherit system ruby pure native other boundBundler;
        name = "synthetic-bundle-${ruby.version}";
        pname = "synthetic-bundle";
        version = ruby.version;
        builder = "/bin/false";
      }) // {
        inherit ruby;
        bundler = boundBundler;
        gems = { tvp-pure = pure; tvp-native = native; tvp-other = other; } // @EXTRA@;
        tvp.kind = "ruby-bundle";
        __tvpSelection.kind = "composition";
      };
      rubyApplication = (builtins.derivation {
        inherit system rubyBundle;
        name = "synthetic-application-@APPLICATION@";
        pname = "synthetic-application";
        version = "@APPLICATION@";
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
        inherit phpWithExtensions rubyBundle rubyApplication postgresql postgresqlAlias postgresqlVariant;
        rubyGem = native;
        rubyGemWithoutProviders = builtins.removeAttrs native [ "nativeProviders" ];
        foreignRuntime = rubyBundle // { ruby = externalLibrary; bundler = externalLibrary; };
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
        inherit (tvp.packages.${system}) rubyBundle rubyApplication rubyGem rubyGemWithoutProviders foreignRuntime;
      };
      devShells.${system} = {
        ruby = builtins.derivation {
          inherit system;
          name = "ruby-consumer-shell";
          builder = "/bin/false";
          buildInputs = [ tvp.packages.${system}.rubyBundle tvp.packages.${system}.postgresql ];
          nativeBuildInputs = [ tvp.legacyPackages.${system}.canonical.ruby_2_7_0 ];
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
        native_version="16.16", application_version="1.0.0", extra_native=False,
    ):
        source = (UPSTREAM.replace("@PHP@", php_version)
                  .replace("@REDIS@", redis_version).replace("@RECIPE@", recipe)
                  .replace("@GEM@", gem_version).replace("@MANAGER@", manager_version)
                  .replace("@NATIVE@", native_version)
                  .replace("@APPLICATION@", application_version)
                  .replace("@EXTRA@", '{ another-native = native // { gemName = "another-native"; }; }' if extra_native else "{ }"))
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

    def test_impure_outputs_require_explicit_flag(self):
        project = self.project / "flake.nix"
        project.write_text(project.read_text().replace(
            'system = "x86_64-linux";',
            '''system =
              if builtins.getEnv "TVP_CONSUMER_TEST_IMPURE" == "enabled"
              then "x86_64-linux"
              else throw "consumer fixture requires --impure";''',
        ))
        self.env["TVP_CONSUMER_TEST_IMPURE"] = "enabled"
        pure = subprocess.run(
            [sys.executable, "-B", str(CLI), "used", "--flake", str(self.project), "--json"],
            cwd=self.root, env=self.env, text=True, capture_output=True,
        )
        self.assertNotEqual(pure.returncode, 0)
        self.assertIn("consumer fixture requires --impure", pure.stderr)

        observed = self.tvp("used", "--impure")
        php = next(row for row in observed["packages"] if row["role"] == "php-engine")
        self.assertEqual(php["version"], "8.2.1")
        self.assertEqual(self.tvp("diff", str(self.lock), "--impure")["changes"], [])

        self.commit_upstream("8.2.2", "6.2.1", "revised")
        preview = self.tvp("update", "--preview", "--impure")
        changes = {row["after"]["pname"]: row for row in preview["changes"]}
        self.assertEqual(changes["php"]["after"]["version"], "8.2.2")
        self.assertEqual(changes["php-redis"]["after"]["version"], "6.2.1")
        self.assertEqual(self.lock.read_bytes(), self.original_lock)

    def test_ruby_reports_only_managed_packages_and_deduplicates_uses(self):
        attribute = f"packages.{SYSTEM}.rubyBundle"
        inventory = self.tvp("used", attribute=attribute)
        packages = {row["pname"]: row for row in inventory["packages"]}
        self.assertEqual(set(packages), {"ruby", "bundler", "postgresql"})
        self.assertEqual({row["role"] for row in packages.values()}, {"package"})
        self.assertEqual(packages["ruby"]["version"], "2.7.0")
        self.assertEqual(packages["bundler"]["version"], "1.17.3")
        self.assertEqual(packages["bundler"]["kind"], "override")
        self.assertEqual(packages["postgresql"]["version"], "16.16")
        self.assertEqual(
            {use["gemName"] for use in packages["postgresql"]["usedBy"]},
            {"tvp-native", "tvp-other"},
        )
        self.assertTrue(all(use["providerName"] == "postgresql" for use in packages["postgresql"]["usedBy"]))
        self.assertTrue(all("gemName" not in row for row in inventory["packages"]))
        self.assertNotIn("external-library", packages)

        shell_inventory = self.tvp("used", attribute=f"devShells.{SYSTEM}.ruby")
        shell = {row["pname"]: row for row in shell_inventory["packages"]}
        self.assertEqual(set(shell), set(packages))
        self.assertEqual(len(shell["postgresql"]["usedBy"]), 3)
        self.assertEqual(len(shell["ruby"]["usedBy"]), 2)
        application_inventory = self.tvp("used", attribute=f"packages.{SYSTEM}.rubyApplication")
        self.assertEqual({row["pname"] for row in application_inventory["packages"]}, set(packages))
        gem_inventory = self.tvp("used", attribute=f"packages.{SYSTEM}.rubyGem")
        self.assertEqual({row["pname"] for row in gem_inventory["packages"]}, {"ruby", "postgresql"})
        without_providers = self.tvp("used", attribute=f"packages.{SYSTEM}.rubyGemWithoutProviders")
        self.assertEqual({row["pname"] for row in without_providers["packages"]}, {"ruby"})
        foreign_runtime = self.tvp("used", attribute=f"packages.{SYSTEM}.foreignRuntime")
        self.assertEqual({row["pname"] for row in foreign_runtime["packages"]}, {"postgresql"})

        self.commit_upstream(
            "8.2.1", "6.2.0", "revised",
            gem_version="1.1.0", manager_version="2.1.2", native_version="16.17",
        )
        comparison = self.tvp("update", "--preview", attribute=attribute)
        self.assertEqual(self.lock.read_bytes(), self.original_lock)
        self.assertEqual({entry["change"] for entry in comparison["changes"]}, {"changed"})
        changes = {row["after"]["pname"]: row for row in comparison["changes"]}
        self.assertEqual(set(changes), {"ruby", "bundler", "postgresql"})
        self.assertTrue(changes["bundler"]["versionChanged"])
        self.assertEqual(changes["bundler"]["after"]["version"], "2.1.2")
        self.assertFalse(changes["ruby"]["versionChanged"])
        self.assertTrue(changes["ruby"]["derivationChanged"])
        self.assertTrue(changes["postgresql"]["versionChanged"])
        self.assertEqual(changes["postgresql"]["after"]["version"], "16.17")
        application_preview = self.tvp("update", "--preview", attribute=f"packages.{SYSTEM}.rubyApplication")
        self.assertEqual({row["after"]["pname"] for row in application_preview["changes"]}, set(changes))
        self.assertEqual(self.lock.read_bytes(), self.original_lock)

    def test_gem_application_and_consumer_reference_changes_are_not_package_updates(self):
        attributes = [f"packages.{SYSTEM}.rubyBundle", f"packages.{SYSTEM}.rubyApplication"]
        for extra_native in (False, True):
            self.commit_upstream(
                "8.2.1", "6.2.0", "original", gem_version="1.1.0",
                application_version="2.0.0", extra_native=extra_native,
            )
            for attribute in attributes:
                with self.subTest(attribute=attribute, extra_native=extra_native):
                    preview = self.tvp("update", "--preview", attribute=attribute)
                    self.assertEqual(preview["changes"], [])
                    self.assertNotEqual(preview["beforeInput"], preview["afterInput"])
            self.assertEqual(self.lock.read_bytes(), self.original_lock)

    def test_distinct_aliases_and_variants_are_preserved(self):
        project = self.project / "flake.nix"
        project.write_text(project.read_text().replace(
            "tvp.packages.${system}.rubyBundle tvp.packages.${system}.postgresql",
            "tvp.packages.${system}.rubyBundle tvp.packages.${system}.postgresql "
            "tvp.packages.${system}.postgresqlAlias tvp.packages.${system}.postgresqlVariant",
        ))
        report = self.tvp("used", attribute=f"devShells.{SYSTEM}.ruby")
        packages = [row for row in report["packages"] if row["pname"] == "postgresql"]
        self.assertEqual(len(packages), 3)
        self.assertEqual({row["selector"] for row in packages}, {"postgresql_16", "postgresql_exact"})
        self.assertEqual(len({row["drvPath"] for row in packages}), 2)


if __name__ == "__main__":
    unittest.main()
