{ tvp, ... }:
let
  pname = "libzip";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          bzip2 = tvp.packages.bzip2;
          openssl = tvp.packages.openssl;
          xz = tvp.packages.xz_5;
          zlib = tvp.packages.zlib_1;
          zstd = tvp.packages.zstd_1;
        };
      };
      releases."1.12.1" = "sha256-xABiAioZY8gFc9SPYHB5IpfOzXxr/+Ou/KwNi5vuiRM=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url = version: "https://libzip.org/download/libzip-${version}.tar.xz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/nih-at/libzip.git";
        prefix = "v";
        include = version: builtins.match "[0-9]+([.][0-9]+)+" version != null;
      };
    };
    tests = import ./tests.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.${pname} = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
