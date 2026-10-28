{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2.42" = {
      builder = ./build-2.42.nix;
      base = tvp.bases.default;
      deps = {
        zlib = tvp.packages.zlib_1_3_2;
        zstd = tvp.packages.zstd_1_5_6;
        perl = tvp.packages.perl_5_44_0;
        pkg-config = tvp.packages."pkg-config_0_29_2";
        # Bootstrap tools still borrowed explicitly until TVP packages them.
        inherit (pkgs) bison texinfo;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."2.42";
      releases."2.42" = "sha256-9uTUH9X8d4sGt4kUV7NiDaXs6hAGxqSkGumYEJ+FqAA=";
    }
  ];
  pname = "binutils";
  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = binutils: import ./tests { inherit pkgs tvpLib binutils; };
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://mirrors.kernel.org/gnu/binutils/";
      pattern = "binutils-[0-9][^\"]*\\.tar\\.xz";
      normalise =
        file:
        if pkgs.lib.hasPrefix "binutils-" file && pkgs.lib.hasSuffix ".tar.xz" file then
          pkgs.lib.removeSuffix ".tar.xz" (pkgs.lib.removePrefix "binutils-" file)
        else
          null;
      include = version: builtins.match "[0-9]+\\.[0-9]+(\\.[0-9]+)?" version != null;
    };
  };
in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
