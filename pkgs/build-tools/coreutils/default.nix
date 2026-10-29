{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "9.5" = {
      builder = ./build-9.5.nix;
      base = tvp.bases.default;
      deps = {
        gmp = tvp.packages.gmp_6_3_0;
        acl = tvp.packages.acl_2_3_2;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."9.5";
      releases."9.5" = "sha256-zTKO3qyS9qZl3p8yPJO3Eq8YWLwuDYjz9xAEaUcKG4o=";
    }
  ];
  pname = "coreutils";
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
