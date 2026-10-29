{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "4.4.36" = {
      builder = ./build-4.4.36.nix;
      base = tvp.bases.default;
      deps.perl = tvp.packages.perl_5_44_0;
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."4.4.36";
      releases."4.4.36" = "sha256-5eH0yu4KAd4q7ibjE4gH1tPKK45nKHlm0f79ZeH9iUM=";
    }
  ];
  pname = "libxcrypt";
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
