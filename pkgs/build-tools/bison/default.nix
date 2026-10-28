{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "3.8.2" = {
      builder = ./build-3.8.2.nix;
      base = tvp.bases.default;
      deps = {
        m4 = tvp.variants.gcc13.m4_1_4_21;
        perl = tvp.packages.perl_5_44_0;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."3.8.2";
      releases."3.8.2" = "sha256-BsnhO99+sk1M62tZIFpPZ8LH5yExGWREMP6C+9FKCrs=";
    }
  ];
  pname = "bison";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }: package: import ./tests { inherit pkgs tvpLib package; }
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions packageArgs;
  variants = tvpLib.packages.mkVariants (
    packageArgs
    // {
      inherit pkgs;
      profiles = {
        gcc13-owned = {
          base = tvp.bases.gcc13-owned;
          versions."3.8.2" = {
            deps = {
              m4 = tvp.packages.m4_1_4_21;
              perl = tvp.bases.gcc13-owned.components.perl;
            };
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
