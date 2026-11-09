{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  retained = previous.recipes.python-build;
  candidate = import ../../../bases/source-gnu { };
  constructionTools = builtins.mapAttrs (
    _: tool:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU preparation tool; avoids a public prerequisite/toolchain cycle.";
    } tool
  ) candidate.tools;
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  definition =
    (tvpLib.packages.mkDefs {
      "3.12.5" = {
        constructor = tvp.builder;
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
        builder = ./native/build-3.12.5.nix;
        source =
          { version, sha256 }:
          import <nix/fetchurl.nix> {
            url = "https://www.python.org/ftp/python/${version}/Python-${version}.tar.xz";
            inherit sha256;
          };
        deps = {
          inherit (constructionTools)
            bash
            coreutils
            python
            binutils
            patchelf
            sed
            grep
            gawk
            diffutils
            findutils
            patch
            gzip
            ;
          file = tvp.packages.file;
          gnumake = constructionTools.make;
          gnutar = constructionTools.tar;
          xz = tvp.packages.xz_5;
          openssl = tvp.packages.openssl_3;
          zlib = tvp.packages.zlib_1;
          bzip2 = tvp.packages.bzip2_1;
          pkg-config = tvp.packages.pkg-config;
        };
        patches = retained.versionTable."3.12.5".def.patches;
        opts = retained.versionTable."3.12.5".def.opts;
      };
    })."3.12.5";
  versionTable = retained.versionTable // {
    "3.12.5" = retained.versionTable."3.12.5" // {
      def = if native then definition else retained.versionTable."3.12.5".def;
    };
  };
  publicArgs = retained // {
    inherit versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        import ./tests/native.nix {
          inherit
            pkgs
            tvp
            tvpLib
            package
            ;
        }
      else
        retained.extraArgs.mkTests package
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "python-build";
in
{
  recipes.${pname} = publicArgs // {
    constructionRecipe = retained;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
