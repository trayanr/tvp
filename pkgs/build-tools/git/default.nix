{ tvp, ... }:
let
  pname = "git";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-2.56.0-current.nix;
        deps = {
          rustc = tvp.packages.rustc_1;
          cargo = tvp.packages.cargo-bootstrap_1;
          perl = tvp.packages.perl_5;
          python = tvp.packages.python_3;
          curl = tvp.packages.curl;
          openssl = tvp.packages.openssl;
          zlib = tvp.packages.zlib;
          expat = tvp.packages.expat;
          pcre2 = tvp.packages.pcre2;
        };
      };
      releases = {
        "2.56.0" = "sha256-JsVsKWs4wGlbJvqV9HXx0BcE0tOOc0ZcowsLL13HidM=";
      };
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.directory {
      url = "https://www.kernel.org/pub/software/scm/git/";
      archive = "git-{version}.tar.xz";
    };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes."git" = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
