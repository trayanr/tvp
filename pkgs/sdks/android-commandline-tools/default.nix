{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  retained = (import ./legacy.nix { inherit pkgs tvp; }).recipes.android-commandline-tools;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  definition =
    (tvpLib.packages.mkDefs {
      "23.0" = {
        constructor = tvp.builder;
        builder = ./native/build-23.0.nix;
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
            url = "https://dl.google.com/android/repository/commandlinetools-linux-16111833_latest.zip";
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
              jdk = tvp.packages.jdk_21;
              androidCli = tvp.lib.packages.withConstraint {
                category = "artifact";
                reason = "Matched pinned Android CLI payload for the released command-line tools.";
              } tvp.canonical.android-cli_1_1_16717390;
            };
        opts = {
          sdkPath = "cmdline-tools/23.0";
          archiveRoot = "cmdline-tools";
          packageMetadata = ./metadata-23.0.xml;
        };
        blob = retained.versionTable."23.0".def.blob;
      };
    })."23.0";
  versionTable = retained.versionTable // {
    "23.0" = retained.versionTable."23.0" // {
      def = if native then definition else retained.versionTable."23.0".def;
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
  pname = "android-commandline-tools";
  canonical = tvpLib.packages.mkVersions publicArgs;
in
{
  recipes.${pname} = publicArgs // {
    constructionRecipe = retained;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
