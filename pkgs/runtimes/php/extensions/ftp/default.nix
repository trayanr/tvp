{ pkgs, tvp }:
let
  name = "ftp";
  pname = "php-${name}";
  inherit
    (import ../bundled-releases.nix {
      inherit pkgs tvp;
      minPHP = "8.2";
      def = release: {
        builder = ./build.nix;
        # Use the same TVP OpenSSL provider as the matching PHP build.
        deps.openssl = release.def.deps.openssl;
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
    testDeps.opensslCli = tvp.packages.openssl;
    tests = import ./tests.nix { inherit tvp; };
    meta = {
      description = "PHP extension for FTP and FTP over TLS";
      homepage = "https://www.php.net/manual/en/book.ftp.php";
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
