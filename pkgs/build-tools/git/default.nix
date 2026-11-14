{ pkgs, tvp }:
let
  previous = import ./retained-index.nix { inherit pkgs tvp; };
  prior = previous.recipes."git";
  retained = prior.constructionRecipe or prior;
  earlier = import ../../../bases/source-gnu { };
  full = tvp.baseTiers.full;
  profileBase = full.override {
    shell = tvp.packages.bash;
    coreutils = tvp.packages.coreutils;
    standardTools = {
      python = earlier.tools.python;
      pkg-config = tvp.packages.pkg-config;
      gnumake = tvp.packages.gnumake;
      gnutar = tvp.packages.gnutar;
      xz = tvp.packages.xz;
      findutils = tvp.packages.findutils;
      diffutils = tvp.packages.diffutils;
      gawk = tvp.packages.gawk;
      sed = tvp.packages.gnused;
      grep = tvp.packages.gnugrep;
      patchelf = tvp.packages.patchelf;
    };
  };
  pname = "git";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-2.56.0-current.nix;
        base = profileBase;
        deps = {
          rustc = tvp.packages.rustc_1;
          cargo = tvp.packages.cargo-bootstrap_1;
          perl = tvp.packages.perl_5;
          python = tvp.packages.python_3;
          curl = tvp.packages.curl;
          openssl = tvp.packages.openssl;
          zlib = tvp.packages.zlib;
          expat = tvp.packages.expat;
          pcre2 = tvp.packages.pcre2;
          binutils = tvp.packages.binutils;
        };
      };
      releases = {
        "2.56.0" = "sha256-JsVsKWs4wGlbJvqV9HXx0BcE0tOOc0ZcowsLL13HidM=";
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
        url = "https://www.kernel.org/pub/software/scm/git/git-${version}.tar.xz";
        inherit sha256;
      };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."git" = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
