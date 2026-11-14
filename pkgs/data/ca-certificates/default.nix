{ pkgs, tvp }:
let
  previous = import ./retained-index.nix { inherit pkgs tvp; };
  prior = previous.recipes."ca-certificates";
  retained = prior.constructionRecipe or prior;
  earlier = import ../../../bases/source-gnu { };
  full = tvp.baseTiers.full;
  profileBase = full.override {
    shell = tvp.packages.bash;
    coreutils = tvp.packages.coreutils;
    standardTools =
      {
      };
  };
  pname = "ca-certificates";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-2026-10-20-current.nix;
        base = profileBase;
        deps =
          {
          };
      };
      releases = {
        "2026-10-20" = "sha256-eW8Tib/qE8DtePZjt2W6r/VKUI5Ug3hr1uznPF4+PL4=";
      };
    }
  ];
  testDeps = (prior.testDeps or { }) // {
    diffutils = tvp.packages.diffutils;
    openssl = tvp.packages.openssl_4;
    grep = tvp.packages.gnugrep;
    findutils = tvp.packages.findutils;
  };
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable testDeps;
    packageMeta = prior.packageMeta or { };
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://curl.se/ca/cacert-${version}.pem";
        inherit sha256;
      };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."ca-certificates" = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
