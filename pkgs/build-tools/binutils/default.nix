{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2.42" = {
      builder = ./build-2.42.nix;
      base = tvp.bases.gcc13;
      deps = {
        zlib = tvp.variants.gcc13.zlib_1_3_2;
        zstd = tvp.variants.gcc13.zstd_1_5_6;
        perl = tvp.variants.gcc13.perl_5_44_0;
        pkg-config = tvp.variants.gcc13."pkg-config_0_29_2";
        # These helpers precede the owned base; its canonical tools follow it.
        bison = tvp.variants.gcc13.bison_3_8_2;
        texinfo = tvp.variants.gcc13.texinfo_7_1;
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
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }: binutils: import ./tests { inherit pkgs tvpLib binutils; }
    ) { inherit pkgs; };
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
  canonical = tvpLib.packages.mkVersions packageArgs;
  variants = tvpLib.packages.mkVariants (
    packageArgs
    // {
      inherit pkgs;
      profiles.gcc13 = {
        base = tvp.bases.gcc13;
        versions."2.42" = {
          deps = {
            bison = tvp.variants.gcc13.bison_3_8_2;
            perl = tvp.variants.gcc13.perl_5_44_0;
            pkg-config = tvp.variants.gcc13.pkg-config_0_29_2;
            texinfo = tvp.variants.gcc13.texinfo_7_1;
            zlib = tvp.variants.gcc13.zlib_1_3_2;
            zstd = tvp.variants.gcc13.zstd_1_5_6;
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
