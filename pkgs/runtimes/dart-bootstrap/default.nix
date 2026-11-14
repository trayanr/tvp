{ pkgs, tvp }:
let
  retained = (import ./legacy.nix { inherit pkgs tvp; }).recipes.dart-bootstrap;
  pname = "dart-bootstrap";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {

          gawk = tvp.packages.gawk;
          unzip = tvp.packages.unzip;
          runtimeLibc = tvp.packages.glibc_2;
          runtimeCompiler = tvp.packages.gcc_16;
        };
        opts = {
          sourceLayout.channel = "beta";
          buildFeatures.startupSmoke = false;
        };
        blob = {
          reason = "The exact upstream Dart SDK bootstrap version pinned by Dart 3.13.7's DEPS file.";
          needs = "A source Dart bootstrap chain which can generate the kernel and compiler snapshots needed for the source SDK build.";
          blocked.package = "dart-bootstrap-from-source";
        };
      };
      releases."3.13.0-103.1.beta" = "sha256-sJpFXJillGn1igtM9yISkOf3mEOgd4MVRfAzLC9Dlu4=";
    }
    {
      def = {
        builder = ./build.nix;
        deps = {

          gawk = tvp.packages.gawk;
          unzip = tvp.packages.unzip;
          runtimeLibc = tvp.packages.glibc_2;
          runtimeCompiler = tvp.packages.gcc_16;
        };
        opts = {
          sourceLayout.channel = "stable";
        };
        blob = {
          reason = "Pinned upstream binary SDK; supplies the matching precompiled DevTools web assets while the VM and language tools are built from source separately.";
          needs = "Source-built Flutter/web tooling to rebuild DevTools and a source Dart bootstrap chain.";
          blocked.package = "dart-devtools-from-source";
        };
      };
      releases."3.13.7" = "sha256-65mu0mbvvLYVxq4hwS9Sz+k1ufIIvMxf6n9kwh6Gcik=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://storage.googleapis.com/dart-archive/channels/${
          if pkgs.lib.hasSuffix ".beta" version then "beta" else "stable"
        }/release/${version}/sdk/dartsdk-linux-x64-release.zip";
        inherit sha256;
      };
    tests = import ./tests/installed.nix;
    testDeps = { };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."dart-bootstrap" = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
