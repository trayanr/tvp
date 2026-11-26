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
        __tvpSelection = { namespace = "packages"; selector = "php-redis"; kind = "exact"; };
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

CONTRACT_UPSTREAM = """{
  outputs = { self }:
    let
      system = "x86_64-linux";
      package = selector: pname: version: recipe:
        (builtins.derivation {
          inherit system pname version recipe;
          name = "${pname}-${version}";
          builder = "/bin/false";
        }) // {
          __tvpSelection = { namespace = "packages"; kind = "exact"; inherit selector; };
        };
      runtime = package "future_1" "future-runtime" "@VERSION@" "same";
      newerRuntime = package "future_1" "future-runtime" "2.0.0" "same";
      manager = (package "future-manager" "future-manager" "1.0.0" "same") // {
        tvp.kind = "ruby-application";
        bundle = throw "contract package references must not invoke legacy readers";
      };
      native = package "native_1" "native-library" "1.0.0" "same";
      alias = native // { __tvpSelection = native.__tvpSelection // { selector = "native_exact"; }; };
      variant = package "native_1" "native-library" "1.0.0" "alternate";
      hidden = package "build-only" "undeclared-build-tool" "1.0.0" "same";
      external = builtins.removeAttrs native [ "__tvpSelection" ];
      nested = (package "nested" "nested-container" "1.0.0" "same") // {
        tvpInventory = { schema = 1; packages = { dependency = native; }; };
      };
      environment = args@{ runtime, primary ? native }:
        (package "future-env" "consumer-environment" "1.0.0" "same") // {
          buildInputs = [ hidden ];
          tvpInventory = {
            schema = 1;
            packages = {
              inherit runtime manager nested;
              native = { inherit primary; shared = [ native alias variant external ]; };
            };
          };
          override = changes: environment (args // changes);
          edit = update: environment (update args);
        };
      original = environment { inherit runtime; };
      malformed = value: original // { tvpInventory = value; };
    in {
      packages.${system} = {
        future = original;
        overridden = original.override { runtime = newerRuntime; };
        edited = original.edit (args: args // { primary = variant; });
        legacyConflict = original // {
          tvp.kind = "ruby-application";
          bundle = throw "legacy reader must not inspect a declared contract";
        };
        empty = malformed { schema = 1; packages = { }; };
        unsupported = malformed { schema = 2; packages = { }; };
        missingSchema = malformed { packages = { }; };
        invalidContract = malformed "not an attribute set";
        missingPackages = malformed { schema = 1; };
        invalidPackages = malformed { schema = 1; packages = [ runtime ]; };
        invalidPackageTree = malformed { schema = 1; packages = runtime; };
        invalidReference = malformed { schema = 1; packages = { nested = [ runtime "not a package" ]; }; };
      };
      devShells.${system}.default = builtins.derivation {
        inherit system;
        name = "future-shell";
        builder = "/bin/false";
        buildInputs = [ original runtime ];
      };
    };
}
"""

CONTRACT_PROJECT = """{
  inputs.tvp.url = @URL@;
  outputs = { self, tvp }: {
    packages.x86_64-linux = tvp.packages.x86_64-linux;
    devShells.x86_64-linux.default = tvp.devShells.x86_64-linux.default;
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
        inventory_contract=False,
    ):
        source = (UPSTREAM.replace("@PHP@", php_version)
                  .replace("@REDIS@", redis_version).replace("@RECIPE@", recipe)
                  .replace("@GEM@", gem_version).replace("@MANAGER@", manager_version)
                  .replace("@NATIVE@", native_version)
                  .replace("@APPLICATION@", application_version)
                  .replace("@EXTRA@", '{ another-native = native // { gemName = "another-native"; }; }' if extra_native else "{ }"))
        if inventory_contract:
            source = (source.replace(
                'tvp.kind = "ruby-gem";',
                '''tvp.kind = "ruby-gem";
          tvpInventory = {
            schema = 1;
            packages = {
              runtime = ruby;
              native = if gemName != "tvp-pure" then { inherit postgresql externalLibrary; } else { };
            };
          };''',
            ).replace(
                'tvp.kind = "ruby-bundle";',
                '''tvp.kind = "ruby-bundle";
        tvpInventory = {
          schema = 1;
          packages = {
            runtime = ruby;
            manager = boundBundler;
            native = builtins.mapAttrs (_: gem: gem.nativeProviders) { inherit pure native other; };
          };
        };''',
            ).replace(
                'tvp.kind = "ruby-application";',
                '''tvp.kind = "ruby-application";
        tvpInventory = rubyBundle.tvpInventory;''',
            ).replace(
                'tvp.kind = "php-runtime";',
                '''tvp.kind = "php-runtime";
        tvpInventory = { schema = 1; packages = { runtime = php; extensions = [ redis ]; }; };''',
            ))
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

    def test_audit_keeps_unmapped_inventory_visible_without_network(self):
        report = self.tvp("audit", "--backend", "osv", "--offline")
        self.assertEqual(report["coverage"], {
            "total": 3, "scanned": 0, "unsupported": 3, "completeForInventory": False,
        })
        self.assertEqual(report["findings"], [])
        self.assertFalse(report["scope"]["environmentComplete"])
        self.assertEqual(self.lock.read_bytes(), self.original_lock)
        result = subprocess.run(
            [sys.executable, "-B", str(CLI), "audit", "--backend", "osv", "--offline",
             "--flake", str(self.project), "--require-coverage", "--json"],
            cwd=self.root, env=self.env, text=True, capture_output=True,
        )
        self.assertEqual(result.returncode, 3, result.stderr)
        self.assertEqual(json.loads(result.stdout)["coverage"]["scanned"], 0)

    def test_audit_cli_reports_fixture_findings_and_policy_exit_codes(self):
        source = (self.upstream / "flake.nix").read_text().replace(
            'tvp = { status.level = "ok"; };',
            '''tvp = {
              status.level = "ok";
              security = {
                schema = 1; purl = "pkg:generic/${pname}";
                cpe = { vendor = "fixture"; product = pname; };
              };
            };''',
        )
        (self.upstream / "flake.nix").write_text(source)
        self.command("git", "add", "flake.nix", cwd=self.upstream)
        self.command("git", "-c", "user.name=TVP test", "-c", "user.email=tvp@example.invalid",
                     "-c", "commit.gpgsign=false", "commit", "--quiet", "-m", "Audit identities",
                     cwd=self.upstream)
        self.command("nix", "flake", "update", "tvp", cwd=self.project)
        current_lock = self.lock.read_bytes()
        executable = self.root / "grype"
        executable.write_text("#!" + sys.executable + "\n" + '''
import json, sys
from pathlib import Path
sbom = json.loads(Path(sys.argv[1].removeprefix("sbom:")).read_text())
matches = []
for index, component in enumerate(sbom["components"]):
    matches.append({
        "artifact": {"id": "scanner-id-" + str(index), "name": component["name"],
                     "version": component["version"], "purl": component["purl"],
                     "cpes": [component["cpe"]] if "cpe" in component else []},
        "vulnerability": {"id": "TEST-ADVISORY-CLI", "severity": "High",
                          "description": "Synthetic CLI advisory", "fix": {"versions": []},
                          "knownExploited": [{"cve": "CVE-2099-0001", "dateAdded": "2026-11-01",
                                               "knownRansomwareCampaignUse": "known"}],
                          "epss": [{"cve": "CVE-2099-0001", "epss": 0.125,
                                    "percentile": 0.9, "date": "2026-11-25"}],
                          "risk": 74.5},
        "matchDetails": [{"type": "exact-direct-match", "matcher": "fixture-matcher"}],
    })
print(json.dumps({"matches": matches, "descriptor": {"name": "grype", "version": "fixture",
    "db": {"schemaVersion": 6, "built": "2026-11-01T00:00:00Z", "valid": True}}}))
''')
        executable.chmod(0o755)
        environment = {**self.env, "PATH": str(self.root) + os.pathsep + self.env["PATH"]}
        command = [sys.executable, "-B", str(CLI), "audit", "--offline",
                   "--flake", str(self.project), "--attr", f"devShells.{SYSTEM}.default",
                   "--fail-on", "high", "--json"]
        result = subprocess.run(command, cwd=self.root, env=environment, text=True, capture_output=True)
        self.assertEqual(result.returncode, 2, result.stderr)
        report = json.loads(result.stdout)
        self.assertEqual(report["coverage"]["scanned"], 2)
        self.assertEqual(report["coverage"]["unsupported"], 1)
        self.assertEqual(len(report["findings"]), 2)
        for finding in report["findings"]:
            self.assertEqual(finding["knownExploited"][0]["cve"], "CVE-2099-0001")
            self.assertEqual(finding["epss"][0]["epss"], 0.125)
            self.assertEqual(finding["risk"], {"source": "grype", "score": 74.5})
        text_result = subprocess.run(command[:-1], cwd=self.root, env=environment, text=True, capture_output=True)
        self.assertEqual(text_result.returncode, 2, text_result.stderr)
        self.assertIn("CISA KEV: CVE-2099-0001 listed", text_result.stdout)
        self.assertIn("EPSS CVE-2099-0001: 12.50%", text_result.stdout)
        self.assertIn("Grype risk: 74.5/100", text_result.stdout)
        self.assertTrue(all(finding["applicability"] == "unassessed" for finding in report["findings"]))
        self.assertTrue(all("usedBy" in component["selections"][0] for component in report["components"]))
        self.assertEqual(self.lock.read_bytes(), current_lock)
        used = self.tvp("used")
        self.assertTrue(all("security" not in package for package in used["packages"]))

    def contract_upstream(self, version):
        (self.upstream / "flake.nix").write_text(CONTRACT_UPSTREAM.replace("@VERSION@", version))
        self.command("git", "add", "flake.nix", cwd=self.upstream)
        self.command(
            "git", "-c", "user.name=TVP test", "-c", "user.email=tvp@example.invalid",
            "-c", "commit.gpgsign=false", "commit", "--quiet", "-m", version,
            cwd=self.upstream,
        )

    def prepare_contract_project(self):
        self.contract_upstream("1.0.0")
        url = "git+" + self.upstream.as_uri()
        (self.project / "flake.nix").write_text(CONTRACT_PROJECT.replace("@URL@", json.dumps(url)))
        self.command("nix", "flake", "update", "tvp", cwd=self.project)
        self.original_lock = self.lock.read_bytes()

    def test_language_independent_contract_and_resolved_overrides(self):
        self.prepare_contract_project()
        attribute = f"packages.{SYSTEM}.future"
        observed = self.tvp("used", attribute=attribute)
        packages = observed["packages"]
        self.assertEqual(len(packages), 5)
        self.assertEqual({row["pname"] for row in packages}, {
            "future-runtime", "future-manager", "native-library",
        })
        native = [row for row in packages if row["pname"] == "native-library"]
        self.assertEqual(len(native), 3)
        self.assertEqual({row["selector"] for row in native}, {"native_1", "native_exact"})
        self.assertEqual(len({row["drvPath"] for row in native}), 2)
        shared = next(row for row in native if len(row["usedBy"]) == 3)
        self.assertTrue(all("tvpInventory.packages" in use["location"] for use in shared["usedBy"]))
        self.assertTrue(all("gemName" not in use for row in packages for use in row["usedBy"]))

        shell = self.tvp("used")
        self.assertEqual(len(shell["packages"]), 5)
        runtime = next(row for row in shell["packages"] if row["pname"] == "future-runtime")
        self.assertEqual(len(runtime["usedBy"]), 2)
        overridden = self.tvp("used", attribute=f"packages.{SYSTEM}.overridden")
        runtime = next(row for row in overridden["packages"] if row["pname"] == "future-runtime")
        self.assertEqual(runtime["version"], "2.0.0")
        edited = self.tvp("used", attribute=f"packages.{SYSTEM}.edited")
        primary = next(row for row in edited["packages"] if any(
            use["location"].endswith(".native.primary") for use in row["usedBy"]
        ))
        variant = next(row for row in native if row["drvPath"] != shared["drvPath"])
        self.assertEqual(primary["drvPath"], variant["drvPath"])
        self.assertEqual(self.tvp("used", attribute=f"packages.{SYSTEM}.legacyConflict")["packages"], packages)
        self.assertEqual(self.tvp("used", attribute=f"packages.{SYSTEM}.empty")["packages"], [])
        self.assertEqual(self.lock.read_bytes(), self.original_lock)

    def test_contract_preview_reports_only_managed_package_changes(self):
        self.prepare_contract_project()
        self.contract_upstream("1.1.0")
        preview = self.tvp("update", "--preview", attribute=f"packages.{SYSTEM}.future")
        self.assertEqual(len(preview["changes"]), 1)
        change = preview["changes"][0]
        self.assertEqual(change["after"]["pname"], "future-runtime")
        self.assertEqual(change["before"]["version"], "1.0.0")
        self.assertEqual(change["after"]["version"], "1.1.0")
        self.assertTrue(change["versionChanged"])
        self.assertEqual(self.lock.read_bytes(), self.original_lock)

    def test_inventory_contract_validation(self):
        self.prepare_contract_project()
        cases = {
            "unsupported": "unsupported tvpInventory schema",
            "missingSchema": "unsupported tvpInventory schema",
            "invalidContract": "tvpInventory must be an attribute set",
            "missingPackages": "tvpInventory.packages must be an attribute set",
            "invalidPackages": "tvpInventory.packages must be an attribute set",
            "invalidPackageTree": "tvpInventory.packages must be an attribute set",
            "invalidReference": "expected a package reference, attribute set or list",
        }
        for name, error in cases.items():
            with self.subTest(name=name):
                result = subprocess.run(
                    [sys.executable, "-B", str(CLI), "used", "--flake", str(self.project),
                     "--attr", f"packages.{SYSTEM}.{name}", "--json"],
                    cwd=self.root, env=self.env, text=True, capture_output=True,
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(error, result.stderr)
        self.assertEqual(self.lock.read_bytes(), self.original_lock)

    def test_metadata_contract_migration_keeps_legacy_package_selections(self):
        attributes = [
            f"packages.{SYSTEM}.rubyBundle", f"packages.{SYSTEM}.rubyApplication",
            f"packages.{SYSTEM}.rubyGem", f"devShells.{SYSTEM}.default",
        ]
        before = {attribute: self.tvp("used", attribute=attribute) for attribute in attributes}
        self.commit_upstream("8.2.1", "6.2.0", "original", inventory_contract=True)
        for attribute in attributes:
            with self.subTest(attribute=attribute):
                preview = self.tvp("update", "--preview", attribute=attribute)
                self.assertEqual(preview["changes"], [])
                self.assertNotEqual(preview["beforeInput"], preview["afterInput"])
        self.assertEqual(self.lock.read_bytes(), self.original_lock)

        self.command("nix", "flake", "update", "tvp", cwd=self.project)
        def identities(report):
            return sorted(json.dumps({
                key: value for key, value in row.items() if key not in ("location", "usedBy")
            }, sort_keys=True) for row in report["packages"])

        for attribute in attributes:
            with self.subTest(attribute=attribute):
                after = self.tvp("used", attribute=attribute)
                self.assertEqual(identities(before[attribute]), identities(after))
                self.assertTrue(any(
                    "tvpInventory.packages" in use["location"]
                    for row in after["packages"] for use in row["usedBy"]
                ))

    def test_preview_matches_lockfile_diff_and_preserves_the_worktree(self):
        inventory = self.tvp("used")
        packages = {row["pname"]: (row["selector"], row["version"]) for row in inventory["packages"]}
        self.assertEqual(packages, {
            "php": ("php_8_2", "8.2.1"),
            "php-redis": ("php-redis", "6.2.0"),
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
        self.assertIn("consumer fixture requires --impure", pure.stdout + pure.stderr)

        observed = self.tvp("used", "--impure")
        php = next(row for row in observed["packages"] if row["pname"] == "php")
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
