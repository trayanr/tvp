{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2.18.3" = {
      constructor = tvp.builder;
      builder = ./build-2.18.3.nix;
      helpers = {
        inherit tvp;
      };
      base = tvp.bases.default;
      deps = {
        inherit (tvp.packages)
          bash
          coreutils
          gnutar
          xz
          ;
        binutils = tvp.packages.binutils_2;
        meson = tvp.packages.meson;
        ninja = tvp.packages.ninja;
        python = tvp.packages.python-build_3;
        pkg-config = tvp.packages.pkg-config;
        gperf = tvp.packages.gperf;
        freetype =
          tvpLib.packages.withConstraint
            {
              category = "construction";
              reason = "Retained freetype counterpart preserves the complete pre-migration fontconfig profile and public variant identities.";
            }
            (
              (tvpLib.packages.mkVersions
                (import ../freetype { inherit pkgs tvp; }).recipes.freetype.constructionRecipe
              ).freetype_2_15_0
            );
        expat = tvp.packages.expat_2;
        patchelf = tvp.packages.patchelf;
      };
    };
  };
  pname = "fontconfig";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."2.18.3";
      releases."2.18.3" = "sha256-T3tVSjjN94wDP2ZsiHHzdJ4UoJT2Wgf2MMke0LQ9NeM=";
    }
  ];
  source =
    { version, sha256 }:
    pkgs.fetchurl {
      url = "https://gitlab.freedesktop.org/api/v4/projects/890/packages/generic/fontconfig/${version}/fontconfig-${version}.tar.xz";
      inherit sha256;
    };
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable source;
    extraArgs.mkTests =
      package:
      import ./tests {
        inherit tvpLib package;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };

      }
      // import ./tests/installed.nix {
        inherit package tvpLib;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
      };
  };
in
packageArgs
