"""Discover public synthetic flake outputs without building any derivations."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


CLI = Path(__file__).with_name("cli.py").resolve()
SYSTEM = "x86_64-linux"
UPSTREAM = r'''{
  outputs = { self }:
    let
      system = "x86_64-linux";
      package = pname: version: recipe:
        (builtins.derivation {
          inherit system pname version recipe;
          name = "${pname}-${version}";
          builder = "/bin/false";
        }) // {
          __tvpSelection = {
            namespace = "packages"; selector = pname; kind = "exact";
            inherit pname version;
          };
        };
      core = package "core" "@VERSION@" "same";
      variant = package "core" "@VERSION@" "different-build";
      extra = package "extra" "1.0.0" "same";
      testDependency = package "test-dependency" "1.0.0" "same";
      formatter = package "formatter" "1.0.0" "same";
      retired = package "retired" "1.0.0" "same";
      introduced = package "introduced" "1.0.0" "same";
      environment = name: packages: builtins.derivation {
        inherit system name;
        builder = "/bin/false";
        buildInputs = packages;
      };
    in {
      fixture = {
        packages = {
          ${system} = {
            main = core;
            "with.dot" = core;
            inherit variant;
            @CHANGING_PACKAGE@
          };
          aarch64-linux = throw "foreign packages must stay lazy";
        };
        devShells = {
          ${system} = {
            api = environment "api-shell" [ core extra ];
            web = environment "web-shell" [ core ];
          };
          aarch64-linux = throw "foreign shells must stay lazy";
        };
        checks.${system} = @CHECKS@;
        formatter.${system} = formatter;
        apps = throw "apps must not be forced during discovery";
        legacyPackages = throw "legacy package sets must not be forced";
        nixosConfigurations = throw "configurations need their own adapter";
        overlays = throw "overlays must not be applied";
        lib = { helper = args: throw "custom helpers must not be applied"; };
      };
    };
}'''
PROJECT = '''{
  inputs.tvp.url = @URL@;
  outputs = { self, tvp }: tvp.fixture;
}'''


class DiscoveryIntegrationTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="tvp-discovery-test-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.upstream = self.root / "upstream"
        self.project = self.root / "consumer"
        self.upstream.mkdir()
        self.project.mkdir()
        self.env = os.environ.copy()
        self.env["TVP_CONSUMER_SYSTEM"] = SYSTEM
        self.env["NIX_CONFIG"] = (
            self.env.get("NIX_CONFIG", "") + "\nextra-experimental-features = nix-command flakes\n"
        )
        self.command("git", "init", "--quiet", cwd=self.upstream)
        self.commit_upstream()
        self.project_source = PROJECT.replace("@URL@", json.dumps("git+" + self.upstream.as_uri()))
        (self.project / "flake.nix").write_text(self.project_source)
        self.command("nix", "flake", "lock", cwd=self.project)
        self.lock = self.project / "flake.lock"
        self.original_lock = self.lock.read_bytes()

    def command(self, *args, cwd):
        result = subprocess.run(args, cwd=cwd, env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, f"{args}\n{result.stdout}{result.stderr}")
        return result.stdout

    def commit_upstream(self, version="1.0.0", *, generation="before", broken_checks=False):
        changing = "retired = retired;" if generation == "before" else "introduced = introduced;"
        checks = ('throw "synthetic check namespace failed"' if broken_checks
                  else '{ smoke = environment "smoke-check" [ core testDependency ]; }')
        source = (UPSTREAM.replace("@VERSION@", version)
                  .replace("@CHANGING_PACKAGE@", changing).replace("@CHECKS@", checks))
        (self.upstream / "flake.nix").write_text(source)
        self.command("git", "add", "flake.nix", cwd=self.upstream)
        self.command("git", "-c", "user.name=TVP test", "-c", "user.email=tvp@example.invalid",
                     "-c", "commit.gpgsign=false", "commit", "--quiet", "-m", "Public fixture",
                     cwd=self.upstream)

    def invoke(self, command, *args, expected=0):
        result = subprocess.run(
            [sys.executable, "-B", str(CLI), command, "--flake", str(self.project), "--json", *args],
            cwd=self.root, env=self.env, text=True, capture_output=True,
        )
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return json.loads(result.stdout)

    def broken_siblings(self):
        (self.project / "flake.nix").write_text(self.project_source.replace(
            "tvp.fixture;",
            '''tvp.fixture // {
              packages = tvp.fixture.packages // {
                x86_64-linux = tvp.fixture.packages.x86_64-linux // {
                  broken = throw "synthetic package failed";
                };
              };
              checks.x86_64-linux = throw "synthetic check namespace failed";
            };''',
        ))

    def test_discovers_supported_outputs_and_retains_all_package_origins(self):
        report = self.invoke("used")
        self.assertIsNone(report["attribute"])
        self.assertEqual(report["scope"], "discovered")
        self.assertEqual(report["system"], SYSTEM)
        self.assertEqual(report["outputCoverage"], {"evaluated": 8, "failed": 0, "complete": True})
        paths = {row["attribute"] for row in report["outputs"]}
        self.assertEqual(paths, {
            f"packages.{SYSTEM}.main", f'packages.{SYSTEM}."with.dot"',
            f"packages.{SYSTEM}.variant", f"packages.{SYSTEM}.retired",
            f"devShells.{SYSTEM}.api", f"devShells.{SYSTEM}.web",
            f"checks.{SYSTEM}.smoke", f"formatter.{SYSTEM}",
        })
        self.assertTrue(all(row["status"] == "evaluated" for row in report["outputs"]))
        self.assertEqual(len(report["packages"]), 6)
        core = [row for row in report["packages"] if row["pname"] == "core"]
        self.assertEqual(len(core), 2)
        self.assertEqual(len({row["drvPath"] for row in core}), 2)
        shared = max(core, key=lambda row: len(row["usedBy"]))
        self.assertEqual({use["attribute"] for use in shared["usedBy"]}, {
            f"packages.{SYSTEM}.main", f'packages.{SYSTEM}."with.dot"',
            f"devShells.{SYSTEM}.api", f"devShells.{SYSTEM}.web", f"checks.{SYSTEM}.smoke",
        })
        skipped = {row["attribute"] for row in report["skippedOutputs"]}
        self.assertTrue({"apps", "legacyPackages", "nixosConfigurations", "overlays", "lib"} <= skipped)
        self.assertEqual(self.lock.read_bytes(), self.original_lock)

    def test_explicit_attribute_bypasses_discovery_and_broken_siblings(self):
        self.broken_siblings()
        for attribute in (f"packages.{SYSTEM}.main", f'packages.{SYSTEM}."with.dot"'):
            with self.subTest(attribute=attribute):
                report = self.invoke("used", "--attr", attribute)
                self.assertEqual(report["attribute"], attribute)
                self.assertEqual(len(report["packages"]), 1)
                self.assertEqual(report["packages"][0]["pname"], "core")
        self.assertEqual(self.lock.read_bytes(), self.original_lock)

    def test_partial_failures_keep_successful_inventory_and_nonzero_json_reports(self):
        self.broken_siblings()
        report = self.invoke("used", expected=1)
        failures = {row["attribute"]: row for row in report["outputs"] if row["status"] == "failed"}
        self.assertEqual(set(failures), {f"packages.{SYSTEM}.broken", f"checks.{SYSTEM}"})
        self.assertIn("synthetic package failed", failures[f"packages.{SYSTEM}.broken"]["error"])
        self.assertIn("synthetic check namespace failed", failures[f"checks.{SYSTEM}"]["error"])
        self.assertEqual(report["outputCoverage"], {"evaluated": 7, "failed": 2, "complete": False})
        self.assertIn("core", {row["pname"] for row in report["packages"]})
        audit = self.invoke("audit", "--backend", "osv", "--offline", expected=1)
        self.assertEqual(audit["coverage"]["total"], len(report["packages"]))
        self.assertFalse(audit["coverage"]["completeForInventory"])
        self.assertEqual(audit["findings"], [])
        self.assertEqual(self.lock.read_bytes(), self.original_lock)

    def test_empty_discovery_is_not_a_clean_security_result(self):
        (self.project / "flake.nix").write_text(self.project_source.replace(
            "tvp.fixture;", '{ lib = {}; apps = throw "unsupported app must stay lazy"; };',
        ))
        report = self.invoke("used")
        self.assertEqual(report["packages"], [])
        self.assertEqual(report["outputs"], [])
        self.assertEqual(report["outputCoverage"], {"evaluated": 0, "failed": 0, "complete": True})
        audit = self.invoke("audit", "--backend", "osv", "--offline", "--require-coverage", expected=3)
        self.assertFalse(audit["coverage"]["completeForInventory"])
        self.assertEqual(audit["coverage"]["total"], 0)
        self.assertEqual(self.lock.read_bytes(), self.original_lock)

    def test_audit_scans_shared_builds_once_and_retains_output_use_sites(self):
        report = self.invoke("audit", "--backend", "osv", "--offline")
        self.assertEqual(report["coverage"]["total"], 6)
        self.assertEqual(report["coverage"]["unsupported"], 6)
        core = [component for component in report["components"] if component["name"] == "core"]
        self.assertEqual(len(core), 2)
        uses = [use for component in core for selection in component["selections"] for use in selection["usedBy"]]
        self.assertEqual(len({use["attribute"] for use in uses}), 6)
        self.assertEqual(self.lock.read_bytes(), self.original_lock)

    def test_preview_and_diff_discover_output_additions_and_removals_under_each_lock(self):
        before = self.root / "before.lock"
        before.write_bytes(self.original_lock)
        self.commit_upstream("1.1.0", generation="after")
        preview = self.invoke("update", "--preview")
        self.assertEqual(self.lock.read_bytes(), self.original_lock)
        self.assertTrue(preview["outputCoverage"]["complete"])
        output_changes = {(row["attribute"], row["change"]) for row in preview["outputChanges"]}
        self.assertEqual(output_changes, {
            (f"packages.{SYSTEM}.retired", "removed"), (f"packages.{SYSTEM}.introduced", "added"),
        })
        changes = preview["changes"]
        self.assertEqual([row["before"]["pname"] for row in changes if row["change"] == "removed"], ["retired"])
        self.assertEqual([row["after"]["pname"] for row in changes if row["change"] == "added"], ["introduced"])
        changed = [row for row in changes if row["change"] == "changed"]
        self.assertEqual(len(changed), 2)
        self.assertTrue(all(row["after"]["pname"] == "core" and row["after"]["version"] == "1.1.0" for row in changed))
        self.command("nix", "flake", "update", "tvp", cwd=self.project)
        self.assertEqual(self.invoke("diff", str(before)), preview)

    def test_failed_namespace_does_not_invent_removed_outputs_or_packages(self):
        before = self.root / "before.lock"
        before.write_bytes(self.original_lock)
        self.commit_upstream(broken_checks=True)
        self.command("nix", "flake", "update", "tvp", cwd=self.project)
        report = self.invoke("diff", str(before), expected=1)
        self.assertFalse(report["outputCoverage"]["complete"])
        self.assertEqual(report["changes"], [])
        self.assertEqual(report["outputChanges"], [])
        failures = [row for row in report["afterOutputs"] if row["status"] == "failed"]
        self.assertEqual([row["attribute"] for row in failures], [f"checks.{SYSTEM}"])
        reversed_report = self.invoke("diff", str(self.lock), str(before), expected=1)
        self.assertFalse(reversed_report["outputCoverage"]["complete"])
        self.assertEqual(reversed_report["changes"], [])
        self.assertEqual(reversed_report["outputChanges"], [])

    def test_candidate_lock_preserves_git_revision_follows_and_relative_inputs(self):
        child = self.project / "child"
        child.mkdir()
        (child / "flake.nix").write_text('{ outputs = { self }: { marker = "relative-child"; }; }')
        source = '''{
          inputs.tvp.url = @URL@;
          inputs.followed.follows = "tvp";
          inputs.child.url = "path:./child";
          outputs = { self, tvp, followed, child }:
            let
              system = "x86_64-linux";
              upstreamVersion = input: input.fixture.packages.${system}.main.version;
              version = "${self.rev}-${upstreamVersion tvp}-${upstreamVersion followed}-${child.marker}";
              context = (builtins.derivation {
                inherit system version;
                name = "locked-context";
                pname = "locked-context";
                builder = "/bin/false";
              }) // {
                __tvpSelection = {
                  namespace = "packages"; selector = "locked-context"; kind = "exact";
                };
              };
            in { packages.${system}.context = context; };
        }'''.replace("@URL@", json.dumps("git+" + self.upstream.as_uri()))
        (self.project / "flake.nix").write_text(source)
        self.command("git", "init", "--quiet", cwd=self.project)
        self.command("git", "add", "flake.nix", "flake.lock", "child/flake.nix", cwd=self.project)
        self.command("nix", "flake", "lock", cwd=self.project)
        self.command("git", "add", "flake.lock", cwd=self.project)
        self.command("git", "-c", "user.name=TVP test", "-c", "user.email=tvp@example.invalid",
                     "-c", "commit.gpgsign=false", "commit", "--quiet", "-m", "Public locked context",
                     cwd=self.project)
        revision = self.command("git", "rev-parse", "HEAD", cwd=self.project).strip()
        original_lock = self.lock.read_bytes()
        before = self.invoke("used")
        self.assertEqual(before["packages"][0]["version"], f"{revision}-1.0.0-1.0.0-relative-child")
        self.commit_upstream("1.1.0")
        preview = self.invoke("update", "--preview")
        self.assertTrue(preview["outputCoverage"]["complete"])
        self.assertEqual(len(preview["changes"]), 1)
        change = preview["changes"][0]
        self.assertEqual(change["before"]["version"], f"{revision}-1.0.0-1.0.0-relative-child")
        self.assertEqual(change["after"]["version"], f"{revision}-1.1.0-1.1.0-relative-child")
        self.assertEqual(self.lock.read_bytes(), original_lock)
        self.assertEqual(self.command("git", "status", "--porcelain", cwd=self.project), "")


if __name__ == "__main__":
    unittest.main()
