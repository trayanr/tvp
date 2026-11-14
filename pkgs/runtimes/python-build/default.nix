{ pkgs, tvp }:
let
  retained = (import ./retained.nix { inherit pkgs tvp; }).recipes.python-build;
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          file = tvp.packages.file;
          xz = tvp.packages.xz_5;
          openssl = tvp.packages.openssl_3;
          zlib = tvp.packages.zlib_1;
          bzip2 = tvp.packages.bzip2_1;
          pkg-config = tvp.packages.pkg-config;
        };
        patches =
          [
            {
              file = ./patches/subprocess-shell.patch;
              reason = "Store-layout adaptation: use the declared Bash instead of /bin/sh, which is absent in Nix build sandboxes.";
            }
          ]
          ++ [
            {
              file = ./patches/ssl-unexpected-eof.patch;
              reason = "OpenSSL can append a failed fatal-alert write after unexpected EOF; preserve CPython's strict/suppressed EOF handling instead of reporting the secondary system error.";
            }
          ];
      };
      releases."3.12.5" = "sha256-+oouEsXmILCfU+ZbzYdVDS5aHi4Ev4upkdzFUROHY5c=";
    }
  ];
  pname = "python-build";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://www.python.org/ftp/python/${version}/Python-${version}.tar.xz";
        inherit sha256;
      };
    tests = import ./tests/installed.nix;
    testDeps.glibc = tvp.packages.glibc_2_39;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.python-build = family // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
