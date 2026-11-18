{ tvp, ... }:
let
  pname = "openldap";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps.openssl = tvp.packages.openssl_3;
      };
      releases."2.6.16" = "sha256-jYRSvD9Wqno5LGLdN3cz+D0TFO7WxS/kQChDmju03xg=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.directory {
      url = "https://www.openldap.org/software/download/OpenLDAP/openldap-release/";
      archive = "openldap-{version}.tgz";
    };
    tests = import ./tests.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.openldap = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
