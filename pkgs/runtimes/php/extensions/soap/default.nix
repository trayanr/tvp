{ pkgs, tvp }:
let
  name = "soap";
  pname = "php-${name}";
  inherit
    (import ../bundled-releases.nix {
      inherit pkgs tvp;
      minPHP = "8.2";
      def = release: {
        builder = ./build.nix;
        deps.libxml2 = tvp.lib.packages.withConstraint {
          reason = "Use the libxml2 selected by this PHP release.";
        } release.def.deps.libxml2;
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
      description = "PHP client and server for SOAP web services";
      homepage = "https://www.php.net/manual/en/book.soap.php";
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
