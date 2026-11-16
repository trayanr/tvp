{ tvp, ... }:
let
  pname = "binutils";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-2.42-current.nix;
        deps = {

          zlib = tvp.packages.zlib;
          zstd = tvp.packages.zstd;
          perl = tvp.packages.perl;
          bison = tvp.packages.bison;
          texinfo = tvp.packages.texinfo;
        };
        opts.cStandard = "gnu17";
      };
      releases = {
        "2.42" = "sha256-9uTUH9X8d4sGt4kUV7NiDaXs6hAGxqSkGumYEJ+FqAA=";
      };
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://mirrors.kernel.org/gnu/binutils/";
      pattern = "binutils-[0-9][^\"]*\\.tar\\.xz";
      normalise = tvp.lib.versions.fromArchiveName {
        prefix = "binutils-";
        suffixes = [ ".tar.xz" ];
      };
      include = version: builtins.match "[0-9]+\\.[0-9]+(\\.[0-9]+)?" version != null;
    };
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/binutils/binutils-${version}.tar.xz";
        inherit sha256;
      };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."binutils" = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
