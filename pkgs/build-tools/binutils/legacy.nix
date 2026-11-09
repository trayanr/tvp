{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2.42" = {
      builder = ./build-2.42.nix;
      base = tvp.bases.default;
      # gprofng 2.42 callbacks require pre-C23 unspecified-argument semantics.
      opts.cStandard = "gnu17";
      deps = {
        zlib = tvp.packages.zlib_1;
        zstd = tvp.packages.zstd_1;
        perl = tvp.packages.perl_5;
        pkg-config = tvp.packages.pkg-config;
        bison = tvp.packages.bison;
        texinfo = tvp.packages.texinfo;
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

in
{
  recipes.${pname} = packageArgs;
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
