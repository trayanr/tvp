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
  variants = tvpLib.packages.mkVariants (
    packageArgs
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = tvp.bases.gcc13;
        versions."4.4.36" = {
          deps = {
            perl = tvp.variants.gcc13.perl_5_44_0;
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
