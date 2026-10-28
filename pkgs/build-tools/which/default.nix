{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2.21" = {
      builder = ./build-2.21.nix;
      base = tvp.bases.default;
      deps = {

      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."2.21";
      releases."2.21" = "sha256-9KJFuUEks3fYtJZGv0IfkVXTaqdhS26/g3BdP/x26q0=";
    }
  ];
  pname = "which";
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
          versions."2.21" = { };
        };
      };
    }
  );

in
{
  inherit canonical variants;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
