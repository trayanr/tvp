{ pkgs, tvp }:
let
  earlier = import ../../../bases/source-gnu { };
  pname = "coreutils";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-9.5-current.nix;
        deps = {

          gmp = tvp.packages.gmp_6;
          acl = tvp.packages.acl_2;
          timezoneData = tvp.lib.packages.withConstraint {
            category = "artifact";
            reason = "Build-only zoneinfo data oracle for upstream gnulib Europe/Paris tests; no executable or runtime ownership claim.";
          } pkgs.tzdata;
        };
      };
      releases = {
        "9.5" = "sha256-zTKO3qyS9qZl3p8yPJO3Eq8YWLwuDYjz9xAEaUcKG4o=";
      };
    }
  ];
  testDeps = {
    locale =
      (tvp.lib.tests.fixtures.forBase {
        builder = tvp.builder;
        base = earlier.base;
      }).gnuLocale;
  };
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/coreutils/coreutils-${version}.tar.xz";
        inherit sha256;
      };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."coreutils" = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
