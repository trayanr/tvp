{ pkgs, tvp }:
let
  previous = import ./retained-index.nix { inherit pkgs tvp; };
  prior = previous.recipes."cargo-bootstrap";
  retained = prior.constructionRecipe or prior;
  earlier = import ../../../bases/source-gnu { };
  full = tvp.baseTiers.full;
  profileBase = full.override {
    shell = earlier.tools.bash;
    coreutils = earlier.tools.coreutils;
    standardTools = {
      python = earlier.tools.python;
      patchelf = earlier.tools.patchelf;
      gnutar = earlier.tools.tar;
      gzip = earlier.tools.gzip;
      sed = earlier.tools.sed;
      grep = earlier.tools.grep;
      gawk = earlier.tools.gawk;
      findutils = earlier.tools.findutils;
    };
  };
  pname = "cargo-bootstrap";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-1.97.1-current.nix;
        base = profileBase;
        deps = {
          binutils = earlier.tools.binutils;
          runtimeLibc = tvp.packages.glibc_2;
          runtimeCompiler = tvp.packages.gcc_16;
        };
        blob = prior.versionTable."1.97.1".def.blob;
      };
      releases = {
        "1.97.1" = "sha256-tM28fMaw7gomZrGHJ2n9sq2Dk7KLY5UvZJO0tADkgys=";
      };
    }
  ];
  testDeps = (prior.testDeps or { }) // {
    rustc = tvp.packages.rustc_1;
  };
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;
    packageMeta = prior.packageMeta or { };
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://static.rust-lang.org/dist/rust-${version}-x86_64-unknown-linux-gnu.tar.gz";
        name = "rust-${version}-x86_64-unknown-linux-gnu.tar.gz";
        inherit sha256;
      };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."cargo-bootstrap" = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
