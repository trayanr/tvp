{ pkgs, tvp }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-4.0.0.nix;
        deps.file = tvp.packages.file;
      };
      releases."4.0.0" = "sha256-lCRFwyRbInMP1Bpnp8XCMdEcsbmTa5wPdjNPt9C0Row=";
    }
    {
      def = {
        builder = ./build-4.0.1.nix;
      };
      releases."4.0.1" = "sha256-ltM6u0uwBwx74P7UJGzThBYYgyX4IEaCFEcZOFRbGsg=";
    }
  ];
  pname = "mpdecimal";
  retained = import ./retained { inherit pkgs tvp; };
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    inherit (retained) packageMeta;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://www.bytereef.org/software/mpdecimal/releases/mpdecimal-${version}.tar.gz";
        inherit sha256;
      };
    tests = import ./tests;
    testDeps = {
      pkgConfig = tvp.packages.pkg-config;
      sentinel = (import ../../../bases/source-gnu/tests/probes.nix { }).sentinel;
      alternateSource = (import ../../../bootstrap/source-cmake-prerequisite-tests.nix { }).alternate;
    };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.mpdecimal = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
