{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  retained = (import ./legacy.nix { inherit pkgs tvp; }).recipes.dart-bootstrap;
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
            url = "https://storage.googleapis.com/dart-archive/channels/stable/release/${version}/sdk/dartsdk-linux-x64-release.zip";
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
          gawk = tvp.packages.gawk;
          unzip = tvp.packages.unzip;
          runtimeLibc = tvp.packages.glibc_2;
          runtimeCompiler = tvp.packages.gcc_16;
        };
        opts = {
          channel = "stable";
        };
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
        import ./tests/native.nix { inherit package; }
      else
        (retained.extraArgs.mkTests.override { inherit pkgs; }) package
    ) { inherit pkgs; };
  };
  pname = "dart-bootstrap";
  canonical = tvpLib.packages.mkVersions publicArgs;
in
{
  recipes.${pname} = publicArgs // {
    constructionRecipe = retained;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
