{ pkgs, tvp }:
let
  previous = import ./retained-index.nix { inherit pkgs tvp; };
  prior = previous.recipes."binutils";
  retained = prior.constructionRecipe or prior;
  earlier = import ../../../bases/source-gnu { };
  full = tvp.baseTiers.full;
  profileBase = full.override {
    shell = tvp.packages.bash;
    coreutils = tvp.packages.coreutils;
    standardTools = {
      python = earlier.tools.python;
      patchelf = earlier.tools.patchelf;
      gnumake = tvp.packages.gnumake;
      gnutar = tvp.packages.gnutar;
      gzip = tvp.packages.gzip;
      xz = tvp.packages.xz;
      gawk = tvp.packages.gawk;
      diffutils = tvp.packages.diffutils;
      findutils = tvp.packages.findutils;
      pkg-config = tvp.packages.pkg-config;
      sed = tvp.packages.gnused;
      grep = tvp.packages.gnugrep;
    };
  };
  pname = "binutils";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-2.42-current.nix;
        base = profileBase;
        deps = {
          binutils = earlier.tools.binutils;
          zlib = tvp.packages.zlib;
          zstd = tvp.packages.zstd;
          perl = tvp.packages.perl;
          bison = tvp.packages.bison;
          texinfo = tvp.packages.texinfo;
        };
        opts.cStandard = "gnu17";
      };
      releases = {
        "2.42" = "sha256-9uTUH9X8d4sGt4kUV7NiDaXs6hAGxqSkGumYEJ+FqAA=";
      };
    }
  ];
  testDeps = (prior.testDeps or { }) // { };
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;
    packageMeta = prior.packageMeta or { };
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/binutils/binutils-${version}.tar.xz";
        inherit sha256;
      };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."binutils" = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
