{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "1.35" = {
      builder = ./build-1.35.nix;
      base = tvp.bases.default;
      deps = {
        acl = tvp.packages.acl_2_3_2;
        attr = tvp.packages.attr_2_5_2;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.35";
      releases."1.35" = "sha256-TWL/NzQux67XSFNTI5MMfPlKz3HDWRiCsmp+pQ8+3BY=";
    }
  ];
  pname = "gnutar";
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
