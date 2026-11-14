{ pkgs, tvp }:
let
  retained = (import ./retained.nix { inherit pkgs tvp; }).recipes.bash;
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-5.2.37.nix;
        deps.ncurses = tvp.packages.ncurses_6;
      };
      releases."5.2.37" = "sha256-lZmyLs0dV4etfTt78MWfMSszltHigRdd0fikAU2mIf8=";
    }
  ];
  pname = "bash";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/bash/bash-${version}.tar.gz";
        inherit sha256;
      };
    tests = import ./tests/installed.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.bash = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
