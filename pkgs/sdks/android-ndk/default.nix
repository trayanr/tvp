{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  retained = (import ./legacy.nix { inherit pkgs tvp; }).recipes.android-ndk;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  definition =
    (tvpLib.packages.mkDefs {
      "30.0.16248370" = {
        constructor = tvp.builder;
        builder = ./native/build-30.0.16248370.nix;
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
            url = "https://dl.google.com/android/repository/android-ndk-r30-linux.zip";
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
              zlib = tvp.packages.zlib_1;
              gnumake = tvp.packages.gnumake;
            };
        opts = {
          sdkPath = "ndk/30.0.16248370";
          archiveRoot = "android-ndk-r30";
          packageMetadata = ./metadata-30.0.16248370.xml;
        };
        blob = retained.versionTable."30.0.16248370".def.blob;
      };
    })."30.0.16248370";
  historical =
    (tvpLib.packages.mkDefs {
      "28.2.13676358" = {
        constructor = tvp.builder;
        builder = ./native/build-28.2.13676358.nix;
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
            url = "https://dl.google.com/android/repository/android-ndk-r28c-linux.zip";
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
              zlib = tvp.packages.zlib_1;
              gnumake = tvp.packages.gnumake;
              perl = candidate.tools.perl;
            };
        opts = {
          sdkPath = "ndk/28.2.13676358";
          archiveRoot = "android-ndk-r28c";
          packageMetadata = ./metadata-28.2.13676358.xml;
        };
        blob = retained.versionTable."28.2.13676358".def.blob;
      };
    })."28.2.13676358";
  versionTable = retained.versionTable // {
    "28.2.13676358" = retained.versionTable."28.2.13676358" // {
      def = if native then historical else retained.versionTable."28.2.13676358".def;
    };
    "30.0.16248370" = retained.versionTable."30.0.16248370" // {
      def = if native then definition else retained.versionTable."30.0.16248370".def;
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
  pname = "android-ndk";
  canonical = tvpLib.packages.mkVersions publicArgs;
in
{
  recipes.${pname} = publicArgs // {
    constructionRecipe = retained;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
