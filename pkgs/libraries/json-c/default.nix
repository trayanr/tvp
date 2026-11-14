{ pkgs, tvp }:
let
  previous = import ./retained-index.nix { inherit pkgs tvp; };
  prior = previous.recipes."json-c";
  retained = prior.constructionRecipe or prior;
  full = tvp.baseTiers.full;
  earlier = import ../../../bases/source-gnu { };
  profileBase = full.override {
    shell = tvp.packages.bash;
    coreutils = tvp.packages.coreutils;
    standardTools = {
      python = earlier.tools.python;
      patchelf = earlier.tools.patchelf;
      cmake = tvp.packages.cmake;
      gnumake = tvp.packages.gnumake;
      gnutar = tvp.packages.gnutar;
      gzip = tvp.packages.gzip;
      patch = tvp.packages.patch;
      findutils = tvp.packages.findutils;
      sed = tvp.packages.gnused;
      diffutils = tvp.packages.diffutils;
    };
  };
  variantBase =
    (import ../../../bases/tiers/construction.nix {
      inherit (pkgs) lib;
      builder = tvp.builder;
    } tvp.bases.default).override
      {
        shell = tvp.packages.bash;
        coreutils = tvp.packages.coreutils;
        standardTools = {
          gnumake = tvp.packages.gnumake;
          gnutar = tvp.packages.gnutar;
          gzip = tvp.packages.gzip;
          sed = tvp.packages.gnused;
          grep = tvp.packages.gnugrep;
          diffutils = tvp.packages.diffutils;
          python = tvp.packages.python-build_3;
          patchelf = tvp.packages.patchelf_0;
          cmake = tvp.packages.cmake;
          patch = tvp.packages.patch;
        };
      };
  pname = "json-c";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-0.19-native.nix;
        base = profileBase;
        deps = {
          binutils = earlier.tools.binutils;
        };
        patches = [
          {
            file = ./patches/posix-test-byte.patch;
            reason = "Emit the same incomplete UTF-8 byte with POSIX printf instead of undeclared xxd in the upstream CLI fixture.";
          }
        ];
      };
      releases = {
        "0.19" = "sha256-N60CSZAuMBvZBSv3EuUR/Mas/07KrUtZAKrZzlZOJt4=";
      };
    }
  ];
  testDeps = (prior.testDeps or { }) // {
    grep = tvp.packages.gnugrep;
    diffutils = tvp.packages.diffutils;
  };
  rawFamily = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;
    packageMeta = prior.packageMeta or { };
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://github.com/json-c/json-c/releases/download/json-c-${version}-20260627/json-c-${version}.tar.gz";
        inherit sha256;
      };
    tests = import ./tests;
  };
  family = rawFamily;
  canonical = tvp.lib.packages.mkVersions family;
  variants = tvp.lib.packages.mkVariants (
    family
    // {
      inherit pkgs;
      profiles.build-steps = {
        base = variantBase;
        versions."0.19".deps = {
          binutils = tvp.bases.default.stdenv.cc.bintools.bintools;
        };
      };
    }
  );
in
{
  recipes."json-c" = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  inherit variants;
  aliases = tvp.lib.packages.mkAliases {
    inherit pname versionTable canonical;
    lines = [ "0" ];
  };
}
