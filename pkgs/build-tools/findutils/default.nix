{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "4.10.0" = {
      builder = ./build-4.10.0.nix;
      base = tvp.bases.default;
      deps = {
        coreutils = tvp.packages.coreutils_9_5;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."4.10.0";
      releases."4.10.0" = "sha256-E4fgtn/yR9Kr3pmPkN+/cMFJE5Glnd/suK5ph4nwpPU=";
    }
  ];
  pname = "findutils";
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
        versions."4.10.0" = {
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
