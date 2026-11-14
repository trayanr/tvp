{ pkgs, tvp }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-5.0.5.nix;
        deps.m4 = tvp.packages.m4;
        # Pre-C99 configure probes omit declarations and use non-prototype ().
        opts.configureCFlags = [
          "-Wno-error=implicit-int"
          "-Wno-error=implicit-function-declaration"
        ];
      };
      releases = {
        "5.0.5" = "sha256-6HAVqCWiRF4WmTHuJ4SdUldqLZ4zjROD3LNv7WjQAG8=";
        "5.1.3" = "sha256-3uLto39P9UHzABmTLbDDf293owujYJI0kzsYGPmwcHE=";
      };
    }
    {
      def = {
        builder = ./build-5.0.5.nix;
        deps.m4 = tvp.packages.m4;
        opts.configureCFlags = [
          "-Wno-error=implicit-int"
          "-Wno-error=implicit-function-declaration"
        ];
        opts.reportedVersion = "6.0.0";
        # t-scanf.c checks HAVE_UNISTD_H before config.h supplies its definition.
        opts.checkCFlags = [ "-Wno-error=implicit-function-declaration" ];
      };
      releases = {
        "6.0.0a" = "sha256-kVbTLtrGlVvFOwIY9fN2P6y4kLc6g11eG5Adz464t2Q=";
      };
    }
    {
      def = {
        builder = ./build-6.1.0.nix;
        deps.m4 = tvp.packages.m4;
      };
      releases = {
        "6.1.0" = "sha256-aNrazOUVsPilT1EO3wfBtjZJK8246NVMVushYiXRaYk=";
        "6.1.1" = "sha256-026cBd9IitYw//F+21AFHWQyNX+c4E40oJs9gYgl6DE=";
        "6.1.2" = "sha256-h7Vl6JqaaE/k6+7duDmdziWZ+ckEmFTKjA373qDiGRI=";

      };
    }
    {
      def = {
        builder = ./build-6.2.0.nix;
        deps.m4 = tvp.packages.m4;
      };
      releases = {
        "6.2.0" = "sha256-JY5s1Rs/vfwYXHFtVfgsCK/1ffDG+9FDz27VYSZ6FSY=";
        "6.2.1" = "sha256-/UgpkSzd0S+EGBw0Ucx1K+IkZD6H+sSXtp7d2txJtPI=";
        "6.3.0" = "sha256-o8K4AgG4nmhhb0rTC8Zq7kknw85Q4zkpyoGdXENTiJg=";
      };
    }

  ];
  packageMeta.upstream = {
    type = "directory-index";
    url = "https://mirrors.kernel.org/gnu/gmp/";
    pattern = "gmp-[0-9][^\"]*\\.tar\\.(gz|bz2|xz)";
    normalise =
      file:
      let
        match = builtins.match "gmp-([0-9]+(\\.[0-9]+)*[a-z]?)\\.tar\\.(gz|bz2|xz)" file;
      in
      if match == null then null else builtins.head match;
    include = version: builtins.match "[0-9]+(\\.[0-9]+)*[a-z]?" version != null;
  };
  pname = "gmp";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable packageMeta;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/gmp/gmp-${version}.tar.xz";
        inherit sha256;
      };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.gmp = family // {
    # Historical/frozen construction stays exact until coordinated activation.
    constructionRecipe = import ./retained {
      inherit
        pkgs
        tvp
        versionTable
        packageMeta
        ;
    };
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
