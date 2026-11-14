{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  retained = previous.recipes.isl;
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
      "0.28" = {
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
        builder = ./native/build-0.28.nix;
        source =
          { version, sha256 }:
          import <nix/fetchurl.nix> {
            url = "https://libisl.sourceforge.io/isl-${version}.tar.xz";
            inherit sha256;
          };
        deps = {
          inherit (constructionTools)
            bash
            coreutils
            xz
            python
            binutils
            patchelf
            sed
            grep
            gawk
            diffutils
            gzip
            findutils
            ;
          gnumake = constructionTools.make;
          gnutar = constructionTools.tar;
          gmp = tvp.packages.gmp_6;
        };

      };
    })."0.28";
  ordinaryDefs = tvpLib.packages.mkDefs {
    "0.20" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-0.20.nix;
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
          url = "https://libisl.sourceforge.io/isl-${version}.tar.xz";
          inherit sha256;
        };
      deps = {
        bash = candidate.tools.bash;
        coreutils = candidate.tools.coreutils;
        gnumake = candidate.tools.make;
        gnutar = candidate.tools.tar;
        xz = candidate.tools.xz;
        python = candidate.tools.python;
        binutils = candidate.tools.binutils;
        patchelf = candidate.tools.patchelf;
        sed = candidate.tools.sed;
        grep = candidate.tools.grep;
        gawk = candidate.tools.gawk;
        diffutils = candidate.tools.diffutils;
        findutils = candidate.tools.findutils;
        gzip = candidate.tools.gzip;
        gmp = tvp.packages.gmp_6;
      };
    };
    "0.26" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-0.26.nix;
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
          url = "https://libisl.sourceforge.io/isl-${version}.tar.xz";
          inherit sha256;
        };
      deps = {
        bash = candidate.tools.bash;
        coreutils = candidate.tools.coreutils;
        gnumake = candidate.tools.make;
        gnutar = candidate.tools.tar;
        xz = candidate.tools.xz;
        python = candidate.tools.python;
        binutils = candidate.tools.binutils;
        patchelf = candidate.tools.patchelf;
        sed = candidate.tools.sed;
        grep = candidate.tools.grep;
        gawk = candidate.tools.gawk;
        diffutils = candidate.tools.diffutils;
        findutils = candidate.tools.findutils;
        gzip = candidate.tools.gzip;
        gmp = tvp.packages.gmp_6;
      };
    };
  };
  ordinaryTable = retained.versionTable // {
    "0.20" = retained.versionTable."0.20" // {
      def = if native then ordinaryDefs."0.20" else retained.versionTable."0.20".def;
    };
    "0.26" = retained.versionTable."0.26" // {
      def = if native then ordinaryDefs."0.26" else retained.versionTable."0.26".def;
    };
    "0.27" = retained.versionTable."0.27" // {
      def = if native then ordinaryDefs."0.26" else retained.versionTable."0.27".def;
    };
  };
  versionTable = ordinaryTable // {
    "0.28" = retained.versionTable."0.28" // {
      def = if native then definition else retained.versionTable."0.28".def;
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
        (import ./legacy.nix { inherit pkgs tvp; }).recipes.isl.extraArgs.mkTests package
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "isl";
in
{
  recipes.${pname} = publicArgs // {
    constructionRecipe = retained;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
