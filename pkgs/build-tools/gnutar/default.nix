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
  variants = tvpLib.packages.mkVariants (
    packageArgs
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = tvp.bases.gcc13;
        versions."1.35" = {
          deps = {
            acl = tvp.variants.gcc13.acl_2_3_2;
            attr = tvp.variants.gcc13.attr_2_5_2;
          };
        };
      };
    }
  );

in
{
  inherit canonical variants;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
