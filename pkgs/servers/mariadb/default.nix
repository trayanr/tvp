{ tvp, ... }:
let
  pname = "mariadb";
  archive = "https://archive.mariadb.org/";
  fmtSource = import <nix/fetchurl.nix> {
    url = "https://github.com/fmtlib/fmt/releases/download/12.2.0/fmt-12.2.0.zip";
    sha256 = "sha256-ovSo1RF4+VTkwzkAf3ft12ugyy42+HpI5aVAPZvlh48=";
  };
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        patches = [
          {
            file = ./patches/wide-curses-header.patch;
            reason = "CMake's FindCurses only sets CURSES_HAVE_CURSES_H in narrow mode. Probe the selected wide header before compiling the client.";
          }
        ];
        deps = {
          bison = tvp.packages.bison_3;
          ncurses = tvp.packages.ncurses_6;
          openssl = tvp.packages.openssl_3_0;
          pcre2 = tvp.packages.pcre2_10;
          readline = tvp.packages.readline_8;
          unzip = tvp.packages.unzip;
          zlib = tvp.packages.zlib_1;
        };
        opts = {
          inherit fmtSource;
          fmtVersion = "12.2.0";
        };
      };
      releases."10.11.20" = "sha256-rFwAP3JZUKTL+YKb2bGRtz+KsPJjDW28YpL8UkTTx8s=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url = version: "${archive}mariadb-${version}/source/mariadb-${version}.tar.gz";
      discovery = {
        type = "directory-index";
        url = archive;
        pattern = ''href="mariadb-10[.]11[.][0-9]+/"'';
        scope = "MariaDB 10.11 LTS source releases";
        normalise =
          link:
          let
            match = builtins.match ''href="mariadb-(10[.]11[.][0-9]+)/"'' link;
          in
          if match == null then null else builtins.head match;
      };
    };
    tests = import ./tests.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.mariadb = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
