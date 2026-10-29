{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "4.9" = {
      builder = ./build-4.9.nix;
      base = tvp.bases.default;
      deps = {
        acl = tvp.packages.acl_2_3_2;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."4.9";
      releases."4.9" = "sha256-biJrcy4c1zlGStaGK9Ghq6QteYKSLaelNRljHSSXUYE=";
    }
  ];
  pname = "gnused";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = package: import ./tests { inherit pkgs tvpLib package; };
  };
  canonical = tvpLib.packages.mkVersions packageArgs;

in
{
  recipes.${pname} = packageArgs;
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
