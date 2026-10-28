{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2.3.2" = {
      builder = ./build-2.3.2.nix;
      base = tvp.bases.default;
      deps = {
        attr = tvp.packages.attr_2_5_2;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."2.3.2";
      releases."2.3.2" = "sha256-XyvbrWKXB6p9hcYj+ZSqih0t7FWnPeUgW6wL9gWKL3w=";
    }
  ];
  pname = "acl";
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
        versions."2.3.2" = {
          deps = {
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
