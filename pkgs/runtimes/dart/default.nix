{ tvp, ... }:
let
  pname = "dart";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {

          bootstrapDart = (
            tvp.lib.packages.withConstraint {
              category = "artifact";
              reason = "Matched released SDK/toolchain payload or profile test artifact; changing its release changes the declared artifact identity.";
            } tvp.canonical."dart-bootstrap_3_13_0_103_1_beta"
          );
          devtoolsAssets = (
            tvp.lib.packages.withConstraint {
              category = "artifact";
              reason = "Matched released SDK/toolchain payload or profile test artifact; changing its release changes the declared artifact identity.";
            } tvp.canonical."dart-bootstrap_3_13_7"
          );
          llvm = tvp.packages.llvm_23;
          gn = tvp.packages.gn;
          git = tvp.packages.git_2;
          curl = tvp.packages.curl_8;
          fetchCertificates = tvp.packages.ca-certificates;
          ca-certificates = tvp.packages.ca-certificates;
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
      releases."3.13.7" = "sha256-zSoUUPM8/rNfGA0zuDarkqZj0TNe5/lTrj68sgMIyZ0=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.directory {
      url = "https://github.com/dart-lang/sdk/archive/refs/tags/";
      archive = "{version}.tar.gz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/dart-lang/sdk";
        include = version: builtins.match "[0-9]+(\\.[0-9]+)+" version != null;
      };
    };
    tests = import ./tests/installed.nix;
    testDeps = {
      nodejs = tvp.packages.nodejs_26;
    };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."dart" = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
