{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "3.11" = {
      builder = ./build-3.11.nix;
      base = tvp.bases.default;
      deps = {
        pcre2 = tvp.packages.pcre2_10_44;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."3.11";
      releases."3.11" = "sha256-HbKu3eidDepCsW2VKPiUyNFdrk4ZC1muzHj1qVEnbqs=";
    }
  ];
  pname = "gnugrep";
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
        versions."3.11" = {
          deps = {
            pcre2 = tvp.variants.gcc13.pcre2_10_44;
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
