{ pkgs, tvp }:
let
  name = "mbstring";
  pname = "php-${name}";
  inherit
    (import ../bundled-releases.nix {
      inherit pkgs tvp;
      minPHP = "8.2";
      def = {
        builder = ./build.nix;
        deps = {
          oniguruma = tvp.lib.packages.withConstraint {
            kind = "foreign";
            reason = "PHP mbregex requires Oniguruma, which TVP does not package yet.";
          } pkgs.oniguruma;
        };
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
    phpPolicy = {
      kind = "bundled";
    };
    tests = import ./tests.nix { inherit tvp; };
    meta = {
      description = "PHP multibyte text and regular expression support";
      homepage = "https://www.php.net/manual/en/book.mbstring.php";
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
