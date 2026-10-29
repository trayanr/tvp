{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "3.11" = {
      builder = ./build-3.11.nix;
      base = tvp.bases.default;
      deps = {
        pcre2 = tvp.packages.pcre2_10_44;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."3.11";
      releases."3.11" = "sha256-HbKu3eidDepCsW2VKPiUyNFdrk4ZC1muzHj1qVEnbqs=";
    }
  ];
  pname = "gnugrep";
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
