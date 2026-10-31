{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "5.2.37" = {
      builder = ./build-5.2.37.nix;
      base = tvp.bases.default;
      # These K&R and unprototyped interfaces predate C23.
      opts.cStandard = "gnu17";
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

in
{
  recipes.${pname} = packageArgs;
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
