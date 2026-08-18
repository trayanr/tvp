{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  versionTable = tvpLib.packages.merge {
    "8" = import ./8.nix { inherit pkgs tvp; };
  };

  canonical = tvpLib.packages.mkVersions {
    inherit (pkgs) callPackage;
    pname = "php";
    inherit versionTable;
    defaultBase = tvp.bases.default;

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
