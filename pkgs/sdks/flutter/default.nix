{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  captured = import ../../../sdks/retained-adapters.nix { inherit pkgs tvp; };
  retained =
    (import ./legacy.nix {
      inherit pkgs;
      tvp = captured.callerTvp;
    }).recipes.flutter;
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
      "3.47.8" = {
        constructor = tvp.builder;
        builder = ./native/build-3.47.8.nix;
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
            url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${version}-stable.tar.xz";
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
          dart = tvpLib.packages.withConstraint {
            category = "artifact";
            reason = "Matched released SDK/toolchain payload or profile test artifact; changing its release changes the declared artifact identity.";
          } tvp.canonical.dart_3_13_7;
          git = tvp.packages.git_2;
          curl = tvp.packages.curl_8;
          gradle = tvp.packages.gradle_9;
          androidSdk = tvp.android.constructionProfiles.flutter;
          jdk = tvp.packages.jdk_21;
          ca-certificates = tvp.packages.ca-certificates;
          gawk = tvp.packages.gawk;
          tar = tool "tar";
          gzip = tool "gzip";
          xz = tool "xz";
          unzip = tvp.packages.unzip;
          python = tvp.packages.python_3;
          which = tvp.packages.which;
          runtimeLibc = tvp.packages.glibc_2;
          runtimeCompiler = tvp.packages.gcc_16;
        };
        opts = { };
        blob = retained.versionTable."3.47.8".def.blob;
      };
    })."3.47.8";
  versionTable = retained.versionTable // {
    "3.47.8" = retained.versionTable."3.47.8" // {
      def =
        if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then
          definition
        else
          retained.versionTable."3.47.8".def;
    };
  };
  publicArgs = retained // {
    inherit versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        import ./tests/native.nix { inherit package; }
      else
        (retained.extraArgs.mkTests.override { inherit pkgs; }) package
    ) { inherit pkgs; };
  };
  pname = "flutter";
  canonical = tvpLib.packages.mkVersions publicArgs;
in
{
  recipes.${pname} = publicArgs // {
    constructionRecipe = retained;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
