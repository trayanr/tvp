{ pkgs, tvp }:
let
  pname = "krb5";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          bison = tvp.packages.bison;
          keyutils = tvp.packages.keyutils_1;
          openssl = tvp.packages.openssl_3_0;
        };
      };
      releases."1.21.3" = "sha256-t6TNXq1n+wi5gLIavRUP9yF+heoyDJ7QxtrdMEhArTU=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url =
        version:
        "https://kerberos.org/dist/krb5/${pkgs.lib.versions.majorMinor version}/krb5-${version}.tar.gz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/krb5/krb5.git";
        normalise =
          tag:
          let
            match = builtins.match "krb5-([0-9]+([.][0-9]+)+)-final" tag;
          in
          if match == null then null else builtins.head match;
        # MIT lists this tarball as withdrawn in its historical releases.
        include = version: version != "1.22";
      };
    };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.${pname} = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
