{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = {
    "8.5.9" = {
      builder = ./build-8.5.nix;
      base = tvp.bases.gcc13;
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
  };

  versionTable = tvpLib.packages.mkTable (import ./8.nix { inherit defs; });

  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    pname = "php";
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

        normalise = tag: if pkgs.lib.hasPrefix "php-" tag then pkgs.lib.removePrefix "php-" tag else null;

        # Pre-releases carry no separator (php-8.5.0RC1, php-8.6.0beta1), so
        # they are matched as infixes rather than suffixes.
        include =
          version:
          builtins.match "[0-9].*" version != null
          && !(
            pkgs.lib.hasInfix "RC" version
            || pkgs.lib.hasInfix "alpha" version
            || pkgs.lib.hasInfix "beta" version
          );
      };
    };
  };

  aliases = {
    php_8_5 = canonical.php_8_5_9;
    php_8 = canonical.php_8_5_9;
    php = canonical.php_8_5_9;
  };
in
canonical // tvpLib.packages.checkAliases { inherit canonical aliases; }
