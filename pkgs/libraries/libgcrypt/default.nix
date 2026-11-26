{ tvp, ... }:
let
  pname = "libgcrypt";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = { inherit (tvp.packages) libgpg-error texinfo; };
      };
      releases."1.12.4" = "sha256-139o9Ih5UQ55ovZZd8zGiYF4HqCSPlvf+sKhk+o9Zg4=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.directory {
      url = "https://gnupg.org/ftp/gcrypt/libgcrypt/";
      archive = "libgcrypt-{version}.tar.bz2";
    };
    tests = import ./tests.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.libgcrypt = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
