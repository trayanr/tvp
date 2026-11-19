{ pkgs, tvp }:
let
  name = "imap";
  pname = "php-${name}";
  deps = {
    c-client = tvp.packages.c-client;
    openssl = tvp.packages.openssl_3;
    libxcrypt = tvp.packages.libxcrypt;
  };
  bundled = import ../bundled-releases.nix {
    inherit pkgs tvp;
    minPHP = "8.2";
    beforePHP = "8.4";
    def = {
      builder = ./build.nix;
      inherit deps;
      opts.bundled = true;
    };
  };
  versionTable =
    bundled.versionTable
    // tvp.lib.packages.mkTable [
      {
        def = {
          builder = ./build.nix;
          deps = deps // {
            php = tvp.packages.php_8_5;
          };
          phpRequirements = {
            min = "8.3.0";
            reason = "IMAP 1.0.3 declares a PHP 8.3.0 minimum in package.xml.";
            source = "https://pecl.php.net/package/imap/1.0.3";
          };
          opts.phpCompatibility = {
            min = "8.4";
            before = "8.6";
          };
        };
        releases."1.0.3" = "sha256-DCwLH5TymQBL6Za4WkJOPRH/ZawKPJgNsyEyiaSj+q8=";
      }
    ];
  family = tvp.lib.php.mkExtensionFamily {
    inherit tvp name;
    inherit versionTable;
    source = tvp.lib.sources.archive {
      url = version: "https://pecl.php.net/get/imap-${version}.tgz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/php/pecl-mail-imap.git";
        scope = "Standalone PECL releases. PHP 8.3 and earlier use their bundled source.";
        include = version: builtins.match "[0-9]+[.][0-9]+[.][0-9]+" version != null;
      };
    };
    phpPolicy = {
      kind = "mixed";
      bundled = {
        before = "8.4";
        reason = "PHP moved IMAP from the bundled source to PECL in PHP 8.4.";
        source = "https://www.php.net/manual/en/imap.installation.php";
      };
    };
    tests = import ./tests.nix { inherit tvp; };
    meta = {
      description = "PHP mail access extension using UW IMAP c-client";
      homepage = "https://www.php.net/manual/en/book.imap.php";
      license = pkgs.lib.licenses.php301;
    };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.${pname} = family;
  inherit canonical versionTable;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
