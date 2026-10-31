{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  platform = tvpLib.platforms.forStdenv tvp.bases.default.stdenv;
  defs = tvpLib.packages.mkDefs {
    "3.13.7" = {
      builder = ./build-3.13.7.nix;
      base = tvp.bases.default;
      deps = {
        bootstrapDart = tvp.packages.dart-bootstrap_3_13_0_103_1_beta;
        devtoolsAssets = tvp.packages.dart-bootstrap_3_13_7;
        python = tvp.packages.python_3_12_16;
        llvm = tvp.packages.llvm_23_1_4;
        gn = tvp.packages.gn_20260707;
        git = tvp.packages.git_2_56_0;
        ninja = tvp.packages.ninja_1_13_2;
        patchelf = tvp.packages.patchelf_0_19_2;
        bash = tvp.packages.bash_5_2_37;
        ca-certificates = tvp.packages.ca-certificates_2026_10_20;
      };
      opts = {
        inherit (platform) dynamicLinker;
        # These are source data, not executable package dependencies.
        sourceLocks = import ./sources-3.13.7.nix;
        buildDevtoolsFromSources = false;
        useCipdToolchainStamps = false;
      };
      patches = [
        {
          file = ./patches/owned-linker.patch;
          reason = "Select the declared LLVM LLD by store path, retaining upstream identical-code folding without relying on a compiler bundle's implicit linker.";
        }
        {
          file = ./patches/toolchain-stamps.patch;
          reason = "CIPD stamps only trigger rebuilds when downloaded tools change in place. Store-owned compiler/sysroot paths already encode their identity; select that profile explicitly without inventing CIPD version files.";
        }
      ];
      blob = {
        reason = "VM, compilers and language tools are compiled from source; matching DevTools web assets are copied from the upstream SDK distribution.";
        needs = "Source-built Flutter/web tooling to rebuild the DevTools application.";
        blocked.package = "dart-devtools-from-source";
      };
    };
  };
  pname = "dart";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."3.13.7";
      releases."3.13.7" = "sha256-zSoUUPM8/rNfGA0zuDarkqZj0TNe5/lTrj68sgMIyZ0=";
    }
  ];
  testDeps = {
    nodejs = tvp.packages.nodejs_26_13_0;
  };
  canonical = tvpLib.packages.mkVersions {
    inherit testDeps;
    infra = {
      inherit (pkgs) lib fetchurl fetchzip;
    };
    inherit pname versionTable;
    extraArgs.mkTests =
      package:
      import ./tests {
        inherit tvpLib package;
        nodejs = testDeps.nodejs;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
      };
  };
in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
