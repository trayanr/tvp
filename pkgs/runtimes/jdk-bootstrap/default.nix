{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  retained = (import ./legacy.nix { inherit pkgs tvp; }).packageArgs;
  candidate = import ../../../bases/source-gnu { };
  selectedTool =
    role: provider:
    if provider ? __tvpSelection then
      provider
    else
      tvpLib.packages.tagSelection {
        namespace = "source-gnu.inputs";
        selector = role;
        kind = "source-base-build-tool";
        reason = "Explicit retained source-GNU tool for binary provider installation or finalization.";
      } provider;
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  definition =
    (tvpLib.packages.mkDefs {
      "21.0.13" = {
        constructor = tvp.builder;
        builder = ./native/build-21.0.13.nix;
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
            url = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-${version}%2B9/OpenJDK21U-jdk_x64_linux_hotspot_${version}_9.tar.gz";
            name = "OpenJDK21U-jdk_x64_linux_hotspot_${version}_9.tar.gz";
            inherit sha256;
          };
        deps =
          (pkgs.lib.mapAttrs selectedTool {
            # Explicit source-owned tools; tag otherwise unlabelled bootstrap roles.
            inherit (candidate.tools)
              bash
              coreutils
              python
              binutils
              patchelf
              tar
              gzip
              sed
              grep
              gawk
              findutils
              ;
          })
          // {
            runtimeLibc = tvp.packages.glibc_2;
            runtimeCompiler = tvp.packages.gcc_16;
            zlib = tvp.packages.zlib_1;
            alsa = tvp.packages.alsa-lib_1;
            fontconfig = tvp.packages.fontconfig_2;
          };
        blob = retained.versionTable."21.0.13".def.blob;
      };
    })."21.0.13";
  versionTable = retained.versionTable // {
    "21.0.13" = retained.versionTable."21.0.13" // {
      def = if native then definition else retained.versionTable."21.0.13".def;
    };
  };
  publicArgs = retained // {
    infra = if native then { inherit (pkgs) lib; } else retained.infra;
    inherit versionTable;
    # Font data only: this does not realize the source JDK or its compiler inputs.
    testDeps = pkgs.lib.optionalAttrs native {
      fontArchive = tvpLib.packages.tagSelection {
        namespace = "upstream-source-fixture";
        selector = "openjdk-21.0.13-ga-font";
        kind = "test-source";
        reason = "Pinned A.ttf fixture for the headless binary seed test; no source JDK build.";
      } (import ../jdk/legacy.nix { inherit pkgs tvp; }).canonical.jdk_21_0_13.src;
    };

    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        import ./tests/native.nix { inherit package; }
      else
        (retained.extraArgs.mkTests.override { inherit pkgs; }) package
    ) { inherit pkgs; };
  };
  pname = "jdk-bootstrap";
  canonical = tvpLib.packages.mkVersions publicArgs;
in
{
  recipes.${pname} = publicArgs // {
    constructionRecipe = retained;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
