{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = tvpLib.packages.mkDefs {
    "8.3.10" = {
      builder = ./build-8.0.nix;
      base = tvp.bases.default;
      deps = {
        openssl = tvp.packages.openssl_3_5_7;
        zlib = tvp.packages.zlib_1_3_2;
        libxml2 = tvp.packages.libxml2_2_15_3;
        readline = tvp.packages.readline_8_3;
        ncurses = tvp.packages.ncurses_6_6;
        sqlite = pkgs.sqlite;
        pkg-config = tvp.packages."pkg-config_0_29_2";
      };
    };

    "8.1.0" = {
      builder = ./build-8.0.nix;
      base = tvp.bases.default;
      deps = {
        openssl = tvp.packages.openssl_3_5_7;
        zlib = tvp.packages.zlib_1_3_2;
        # 8.3.9 and older use ATTRIBUTE_UNUSED from libxml2's public headers,
        # which 2.14 removed.
        libxml2 = tvp.packages.libxml2_2_13_9;
        readline = tvp.packages.readline_8_3;
        ncurses = tvp.packages.ncurses_6_6;
        sqlite = pkgs.sqlite;
        pkg-config = tvp.packages."pkg-config_0_29_2";
      };
    };

    "8.0.0" = {
      builder = ./build-8.0.nix;
      base = tvp.bases.default;
      deps = {
        # 8.0 predates PHP's OpenSSL 3 support: ext/openssl uses
        # RSA_SSLV23_PADDING, which 3.0.0 removed.
        openssl = tvp.packages.openssl_1_1_1w;
        zlib = tvp.packages.zlib_1_3_2;
        libxml2 = tvp.packages.libxml2_2_13_9;
        readline = tvp.packages.readline_8_3;
        ncurses = tvp.packages.ncurses_6_6;
        sqlite = pkgs.sqlite;
        pkg-config = tvp.packages."pkg-config_0_29_2";
      };
    };
  };

  versionTable = tvpLib.packages.mkTable (import ./8.nix { inherit defs; });

  pname = "php";

  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname;
    inherit versionTable;

    extraArgs = {
      mkTests =
        php:
        import ./tests {
          inherit pkgs tvpLib php;
        };
    };

    packageMeta = {
      upstream = {
        type = "git-tags";
        url = "https://github.com/php/php-src";

        normalise =
          tag:
          if pkgs.lib.hasPrefix "php-" tag then
            pkgs.lib.removeSuffix "REL" (pkgs.lib.removePrefix "php-" tag)
          else
            null;

        # Upstream tags pre-releases in a dozen spellings — RC1, rc1, beta1, b1,
        # dev, pre1 — so a release is recognised by its shape instead: three
        # numbers, plus the patch-level suffix PHP 4 used.
        include = version: builtins.match "[0-9]+\\.[0-9]+\\.[0-9]+(pl[0-9]+)?" version != null;
      };
    };
  };

in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases {
    inherit
      pname
      versionTable
      canonical
      ;
  };
}
