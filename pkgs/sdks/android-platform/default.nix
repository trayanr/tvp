{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  retained = (import ./legacy.nix { inherit pkgs tvp; }).recipes.android-platform;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  definition =
    (tvpLib.packages.mkDefs {
      "37.2-r2" = {
        constructor = tvp.builder;
        builder = ./native/build-37.2-r2.nix;
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
            url = "https://dl.google.com/android/repository/platform-37.2_r02.zip";
            inherit sha256;
          };
        deps =
          pkgs.lib.mapAttrs
            (
              role: provider:
              if provider ? __tvpSelection then
                provider
              else
                tvpLib.packages.tagSelection {
                  namespace = "source-gnu.inputs";
                  selector = role;
                  kind = "source-base-build-tool";
                  reason = "Explicit candidate-base provider for Android payload installation, host finalization or owned tests; preserve its construction generation.";
                } provider
            )
            {
              inherit (candidate.tools)
                bash
                coreutils
                python
                binutils
                patchelf
                sed
                grep
                diffutils
                findutils
                ;
              runtimeLibc = candidate.toolchain.libc;
              runtimeCompiler = candidate.toolchain.runtime;
              unzip = tvp.packages.unzip;
            };
        opts = {
          sdkPath = "platforms/android-37.2";
          archiveRoot = "android-37.2";
          packageMetadata = ./metadata-37.2-r2.xml;
          apiLevel = "37.2";
        };
        blob = retained.versionTable."37.2-r2".def.blob;
      };
    })."37.2-r2";
  versionTable = retained.versionTable // {
    "37.2-r2" = retained.versionTable."37.2-r2" // {
      def = if native then definition else retained.versionTable."37.2-r2".def;
    };
  };
  publicArgs = retained // {
    inherit versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        import ./tests/native.nix { inherit pkgs tvpLib package; }
      else
        (retained.extraArgs.mkTests.override { inherit pkgs; }) package
    ) { inherit pkgs; };
  };
  pname = "android-platform";
  canonical = tvpLib.packages.mkVersions publicArgs;
in
{
  recipes.${pname} = publicArgs // {
    constructionRecipe = retained;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
