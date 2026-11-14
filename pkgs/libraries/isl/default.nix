{ pkgs, tvp }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-0.20.nix;
        deps.gmp = tvp.packages.gmp_6;
      };
      releases."0.20" = "sha256-pVlqn7ils2XLYS5LlihzXW5n6RePrhNKgWrhlQF+d6o=";
    }
    {
      def = {
        builder = ./build-0.26.nix;
        deps.gmp = tvp.packages.gmp_6;
      };
      releases = {
        "0.26" = "sha256-oLXLBtJPn6nne1X6u+mjyUozYZA0XCVV+ZFbs46XZQQ=";
        "0.27" = "sha256-bYurtZ57Zy6Mt4cOh08/e4E7bgDmrz+LBPdXmWVkPVw=";
        "0.28" = "sha256-PcMbjhsYMp5C1d+/hN1V4VxZthVpoqskb2FJfZWS9yc=";
      };
    }
  ];
  packageMeta.upstream = {
    type = "directory-index";
    url = "https://libisl.sourceforge.io/";
    pattern = "href=\"[^\"]*\"";
    normalise =
      href:
      let
        link = builtins.match ''href="([^"]*)"'' href;
        match =
          if link == null || pkgs.lib.hasSuffix "/" (builtins.head link) then
            null
          else
            builtins.match ''isl-([0-9]+(\.[0-9]+)*)\.tar\.(gz|bz2|xz)'' (
              builtins.baseNameOf (builtins.head link)
            );
      in
      if match == null then null else builtins.head match;
  };
  pname = "isl";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable packageMeta;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://libisl.sourceforge.io/isl-${version}.tar.xz";
        inherit sha256;
      };
    testDeps = {
      python3 = tvp.packages.python_3;
      pkg-config = tvp.packages.pkg-config;
    };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.isl = family // {
    # Frozen observers retain this exact historical definition until MIG-007.
    constructionRecipe = (import ./legacy.nix { inherit pkgs tvp; }).recipes.isl;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
