{ tvp, ... }:
let
  pname = "libraw";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          jpeg = tvp.packages.libjpeg-turbo;
          zlib = tvp.packages.zlib_1;
        };
      };
      releases."0.22.3" = "sha256-eJ88M0ZiEKGgkH90epfHFdIbv0r3EvJX/LvZARGyJ+Q=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url = version: "https://www.libraw.org/data/LibRaw-${version}.tar.gz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/LibRaw/LibRaw.git";
        include = version: builtins.match "[0-9]+\\.[0-9]+\\.[0-9]+" version != null;
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
