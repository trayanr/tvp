{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "5.0.5" = {
      builder = ./build-5.0.5.nix;
      base = tvp.bases.default;
      deps.m4 = tvp.packages.m4_1_4_21;
      # The long-long configure probe defines g() then calls it with arguments.
      # C23 interprets () as (void); retain the intended pre-C23 semantics.
      # The procedure leaves earlier compiler construction byte-identical.
      opts.cStandard = "gnu17";
      # Old h(){} / g(){} configure probes omit types/declarations.
      # Keep C99-guarded upstream arithmetic tests enabled during the build/check.
      opts.configureCFlags = [
        "-Wno-error=implicit-int"
        "-Wno-error=implicit-function-declaration"
      ];
    };
    "6.0.0a" = {
      builder = ./build-5.0.5.nix;
      base = tvp.bases.default;
      deps.m4 = tvp.packages.m4_1_4_21;
      # The long-long configure probe defines g() then calls it with arguments.
      # C23 interprets () as (void); retain the intended pre-C23 semantics.
      # The procedure leaves earlier compiler construction byte-identical.
      opts.cStandard = "gnu17";
      # Old h(){} / g(){} configure probes omit types/declarations.
      # Keep C99-guarded upstream arithmetic tests enabled during the build/check.
      opts.configureCFlags = [
        "-Wno-error=implicit-int"
        "-Wno-error=implicit-function-declaration"
      ];
      opts.reportedVersion = "6.0.0";
      # t-scanf.c tests HAVE_UNISTD_H before including config.h, so unlink's
      # declaration is missed. 6.1.0 includes config.h first. Keep the warning
      # and original upstream test, demoting only this check-time diagnostic.
      opts.checkCFlags = [ "-Wno-error=implicit-function-declaration" ];
    };
    "6.1.0" = {
      builder = ./build-5.0.5.nix;
      base = tvp.bases.default;
      deps.m4 = tvp.packages.m4_1_4_21;
      # Newer probes have explicit return types but still require pre-C23 ().
      opts.cStandard = "gnu17";
    };

  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."5.0.5";
      releases = {
        "5.0.5" = "sha256-6HAVqCWiRF4WmTHuJ4SdUldqLZ4zjROD3LNv7WjQAG8=";
        "5.1.3" = "sha256-3uLto39P9UHzABmTLbDDf293owujYJI0kzsYGPmwcHE=";
      };
    }
    {
      def = defs."6.0.0a";
      releases = {
        "6.0.0a" = "sha256-kVbTLtrGlVvFOwIY9fN2P6y4kLc6g11eG5Adz464t2Q=";
      };
    }
    {
      def = defs."6.1.0";
      releases = {
        "6.1.0" = "sha256-aNrazOUVsPilT1EO3wfBtjZJK8246NVMVushYiXRaYk=";
        "6.1.1" = "sha256-026cBd9IitYw//F+21AFHWQyNX+c4E40oJs9gYgl6DE=";
        "6.1.2" = "sha256-h7Vl6JqaaE/k6+7duDmdziWZ+ckEmFTKjA373qDiGRI=";
        "6.2.0" = "sha256-JY5s1Rs/vfwYXHFtVfgsCK/1ffDG+9FDz27VYSZ6FSY=";
        "6.2.1" = "sha256-/UgpkSzd0S+EGBw0Ucx1K+IkZD6H+sSXtp7d2txJtPI=";
        "6.3.0" = "sha256-o8K4AgG4nmhhb0rTC8Zq7kknw85Q4zkpyoGdXENTiJg=";
      };
    }
  ];
  pname = "gmp";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      gmp:
      import ./tests {
        inherit tvpLib gmp;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = gmp.stdenv;
        };
      }
    ) { inherit pkgs; };
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
  };
  canonical = tvpLib.packages.mkVersions packageArgs;

in
{
  recipes.${pname} = packageArgs;
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
