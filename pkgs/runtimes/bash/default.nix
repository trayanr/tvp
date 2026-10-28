{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "5.2.37" = {
      builder = ./build-5.2.37.nix;
      base = tvp.bases.default;
      deps = {
        ncurses = tvp.packages.ncurses_6_6;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."5.2.37";
      releases."5.2.37" = "sha256-lZmyLs0dV4etfTt78MWfMSszltHigRdd0fikAU2mIf8=";
    }
  ];
  pname = "bash";
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
        versions."5.2.37" = {
          deps = {
            ncurses = tvp.variants.gcc13.ncurses_6_6;
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
