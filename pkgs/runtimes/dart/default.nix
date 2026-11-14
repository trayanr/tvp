{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  captured = import ../../../sdks/retained-adapters.nix { inherit pkgs tvp; };
  retained =
    (import ./legacy.nix {
      inherit pkgs;
      tvp = captured.callerTvp;
    }).recipes.dart;
  candidate = import ../../../bases/source-gnu { };
  tool =
    role:
    tvpLib.packages.tagSelection {
      namespace = "source-gnu.inputs";
      selector = role;
      kind = "source-base-build-tool";
      reason = "Explicit retained owned tool for SDK source preparation or finalization.";
    } candidate.tools.${role};
  definition =
    (tvpLib.packages.mkDefs {
      "3.13.7" = {
        constructor = tvp.builder;
        builder = ./native/build-3.13.7.nix;
        base = candidate.base;
        helpers = {
          inherit tvp;
        };
        testContext =
          package:
          tvpLib.tests.fromPackage {
            builder = tvp.builder;
            inherit package;
          };
        source =
          { version, sha256 }:
          import <nix/fetchurl.nix> {
            url = "https://github.com/dart-lang/sdk/archive/refs/tags/${version}.tar.gz";
            inherit sha256;
          };
        deps = {

          bash = tool "bash";
          coreutils = tool "coreutils";
          helperPython = tool "python";
          binutils = tool "binutils";
          patchelf = tool "patchelf";
          findutils = tool "findutils";
          sed = tool "sed";
          grep = tool "grep";
          diffutils = tool "diffutils";
          bootstrapDart = (
            tvp.lib.packages.withConstraint {
              category = "artifact";
              reason = "Matched released SDK/toolchain payload or profile test artifact; changing its release changes the declared artifact identity.";
            } captured.canonical."dart-bootstrap_3_13_0_103_1_beta"
          );
          devtoolsAssets = (
            tvp.lib.packages.withConstraint {
              category = "artifact";
              reason = "Matched released SDK/toolchain payload or profile test artifact; changing its release changes the declared artifact identity.";
            } tvp.canonical."dart-bootstrap_3_13_7"
          );
          gawk = tvp.packages.gawk;
          python = tvp.packages.python_3;
          llvm = tvp.packages.llvm_23;
          gn = tvp.packages.gn;
          git = tvp.packages.git_2;
          ninja = tvp.packages.ninja;
          curl = tvp.packages.curl_8;
          tar = tool "tar";
          gzip = tool "gzip";
          patch = tool "patch";
          fetchCertificates = tvp.packages.ca-certificates;
          ca-certificates = tvp.packages.ca-certificates;
        };
        opts = {
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
        blob = retained.versionTable."3.13.7".def.blob;
      };
    })."3.13.7";
  versionTable = retained.versionTable // {
    "3.13.7" = retained.versionTable."3.13.7" // {
      def =
        if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then
          definition
        else
          retained.versionTable."3.13.7".def;
    };
  };
  publicArgs = retained // {
    inherit versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        import ./tests/native.nix {
          inherit package;
          inherit tvpLib;
        }
      else
        (retained.extraArgs.mkTests.override { inherit pkgs; }) package
    ) { inherit pkgs; };
  };
  pname = "dart";
  canonical = tvpLib.packages.mkVersions publicArgs;
in
{
  recipes.${pname} = publicArgs // {
    constructionRecipe = retained;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
