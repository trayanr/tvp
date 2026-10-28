{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "3.10" = {
      builder = ./build-3.10.nix;
      base = tvp.bases.default;
      deps = {
        coreutils = tvp.packages.coreutils_9_5;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."3.10";
      releases."3.10" = "sha256-kOXpPMck5OvhLt6A3xY0Bjx6hVaSaFkZv+YLVWyb0J4=";
    }
  ];
  pname = "diffutils";
  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = package: import ./tests { inherit pkgs tvpLib package; };
  };
in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
