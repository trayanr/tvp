{ pkgs, tvp }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
      };
      releases = {
        "3.1" = "sha256-WIVGuUW7pLcLajphboC0q0ZuPzMCSjUvwhmBEs27OuI=";
        "3.2" = "sha256-4N2t67OWkGo+PkysL2l8jWq5Lf+l02WlvCPH1B0w72I=";
        "3.2.1" = "sha256-7VrTF4WOCputu62nDfQBlAAuFuiDSsJEkTB8iPlvlwI=";
        "3.3" = "sha256-/Yfgq6fkOuBUg3r9bNTbA6PyaT3rNhkIXm7Z2NlgStg=";
      };
    }
  ];
  packageMeta.upstream = {
    type = "directory-index";
    url = "https://mirrors.kernel.org/gnu/gperf/";
    pattern = "gperf-[0-9]+(\\.[0-9]+)*\\.tar\\.(gz|bz2|xz|lz)";
    normalise =
      file:
      let
        matched = builtins.match "gperf-([0-9]+(\\.[0-9]+)*)\\.tar\\.(gz|bz2|xz|lz)" file;
      in
      if matched == null then null else builtins.head matched;
    include = version: builtins.match "[0-9]+(\\.[0-9]+)*" version != null;
  };
  pname = "gperf";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable packageMeta;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://ftpmirror.gnu.org/gperf/gperf-${version}.tar.gz";
        inherit sha256;
      };
    tests = import ./tests/installed.nix;
    testDeps = {
      sentinel = (import ../../../bases/source-gnu/tests/probes.nix { }).sentinel;
      alternateSource = (import ../../../bootstrap/source-cmake-prerequisite-tests.nix { }).alternate;
    };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.gperf = family // {
    constructionRecipe = (import ./legacy.nix { inherit pkgs tvp; }).recipes.gperf;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
