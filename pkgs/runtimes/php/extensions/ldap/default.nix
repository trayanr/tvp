{ pkgs, tvp }:
let
  name = "ldap";
  pname = "php-${name}";
  inherit
    (import ../bundled-releases.nix {
      inherit pkgs tvp;
      minPHP = "8.2";
      def = {
        builder = ./build.nix;
        deps.openldap = tvp.packages.openldap;
      };
    })
    source
    versionTable
    ;
  family = tvp.lib.php.mkExtensionFamily {
    inherit
      tvp
      name
      versionTable
      source
      ;
    phpPolicy.kind = "bundled";
    tests = import ./tests.nix { inherit tvp; };
    meta = {
      description = "LDAP directory client for PHP";
      homepage = "https://www.php.net/manual/en/book.ldap.php";
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
