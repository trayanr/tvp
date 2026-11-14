{ pkgs, tvp }:
let
  previous = import ./retained-index.nix { inherit pkgs tvp; };
  prior = previous.recipes."patchelf";
  retained = prior.constructionRecipe or prior;
  full = tvp.baseTiers.full;
  earlier = import ../../../bases/source-gnu { };
  profileBase = full.override {
    shell = tvp.packages.bash;
    coreutils = tvp.packages.coreutils;
    standardTools = {
      python = earlier.tools.python;
      patchelf = earlier.tools.patchelf;
      gnumake = tvp.packages.gnumake;
      gnutar = tvp.packages.gnutar;
      bzip2 = tvp.packages.bzip2;
      gzip = tvp.packages.gzip;
      sed = tvp.packages.gnused;
      grep = tvp.packages.gnugrep;
      diffutils = tvp.packages.diffutils;
      findutils = tvp.packages.findutils;
      gawk = tvp.lib.packages.withConstraint {
        reason = "Patchelf precedes MPFR; use the MPFR-free Gawk 4.0 construction role.";
      } tvp.packages.gawk_4_0;
    };
  };
  pname = "patchelf";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-0.19.2-native.nix;
        base = profileBase;
        deps = {
          cxxRuntime = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Exact full source-GNU C++ runtime selected by the current driver; the public compiler consumes Patchelf.";
          } earlier.toolchain.runtime;
          binutils = earlier.tools.binutils;
        };
      };
      releases = {
        "0.19.2" = "sha256-1K2aTlxongkRnOLzCpSw6LT5jHhZASPqIWZeNMaSiAE=";
      };
    }
  ];
  testDeps = (prior.testDeps or { }) // { };
  rawFamily = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;
    packageMeta = prior.packageMeta or { };
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://github.com/NixOS/patchelf/releases/download/${version}/patchelf-${version}.tar.bz2";
        inherit sha256;
      };
    tests = import ./tests;
  };
  family = rawFamily;
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."patchelf" =
    family // { constructionRecipe = retained; } // { inherit (prior) constructionBuilder; };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
