{ tvp, ... }:
let
  earlier = import ../../../bases/source-gnu { };
  pname = "less";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-710-current.nix;
        deps = {
          ncurses = tvp.packages.ncurses_6;
          pcre2 = tvp.packages.pcre2_10;
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
  testDeps = {
    diffutils = earlier.tools.diffutils;
    perl = earlier.tools.perl;
  };
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://www.greenwoodsoftware.com/less/download.html";
      pattern = "less-[0-9]+\\.tar\\.gz";
      normalise =
        file:
        let
          m = builtins.match "less-([0-9]+)\\.tar\\.gz" file;
        in
        if m == null then null else builtins.head m;
      include = version: builtins.match "[0-9]+" version != null;
    };
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://www.greenwoodsoftware.com/less/less-${version}.tar.gz";
        inherit sha256;
      };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."less" = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
