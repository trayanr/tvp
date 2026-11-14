{ pkgs, tvp }:
let
  previous = import ./retained-index.nix { inherit pkgs tvp; };
  prior = previous.recipes."less";
  retained = prior.constructionRecipe or prior;
  full = tvp.baseTiers.full;
  earlier = import ../../../bases/source-gnu { };
  profileBase = full.override {
    standardTools = {
      gnumake = earlier.tools.make;
      gnutar = earlier.tools.tar;
      gzip = earlier.tools.gzip;
      findutils = earlier.tools.findutils;
      sed = earlier.tools.sed;
      grep = earlier.tools.grep;
      gawk = earlier.tools.gawk;
      python = earlier.tools.python;
      patchelf = earlier.tools.patchelf;
      patch = earlier.tools.patch;
    };
  };
  pname = "less";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-710-current.nix;
        base = profileBase;
        deps = {
          ncurses = tvp.packages.ncurses_6;
          pcre2 = tvp.packages.pcre2_10;
          binutils = earlier.tools.linker;
        };
        patches = [
          {
            file = ./patches/bulk-preprocessor-errors.patch;
            reason = "With explicit --show-preproc-error and captured output, report preprocessor failures on stderr and return nonzero; keep interactive/default fallback behavior.";
          }
        ];
      };
      releases = {
        "710" = "sha256-0QCPt43K4TI92rZkvLNSph8CKxsTG9gBhUjgIdl17Ho=";
      };
    }
  ];
  testDeps = (prior.testDeps or { }) // {
    diffutils = earlier.tools.diffutils;
    perl = earlier.tools.perl;
  };
  rawFamily = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;
    packageMeta = prior.packageMeta or { };
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://www.greenwoodsoftware.com/less/less-${version}.tar.gz";
        inherit sha256;
      };
    tests = import ./tests;
  };
  family = rawFamily;
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."less" = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
