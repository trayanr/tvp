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
        versions."3.10" = {
          deps = {
            coreutils = tvp.variants.gcc13.coreutils_9_5;
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
