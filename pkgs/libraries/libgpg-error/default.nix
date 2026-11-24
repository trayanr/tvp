{ tvp, ... }:
let
  pname = "libgpg-error";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = { inherit (tvp.packages) gettext texinfo; };
      };
      releases."1.61" = "sha256-eoVBPyvDVPT4qoMrcYrxIuSJZeng65AS7mWcE8Y4XJM=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.directory {
      url = "https://gnupg.org/ftp/gcrypt/libgpg-error/";
      archive = "libgpg-error-{version}.tar.bz2";
    };
    tests = import ./tests.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.libgpg-error = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
