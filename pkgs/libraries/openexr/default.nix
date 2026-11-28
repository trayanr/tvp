{ tvp, ... }:
let
  pname = "openexr";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          imath = tvp.packages.imath;
          zstd = tvp.packages.zstd_1;
        };
      };
      releases."3.5.5" = "sha256-ZmmehKMft4dGHw/b7/dQdHmuQJYRnToSZw+brtuCiOs=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url =
        version:
        "https://github.com/AcademySoftwareFoundation/openexr/releases/download/v${version}/openexr-${version}.tar.gz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/AcademySoftwareFoundation/openexr";
        prefix = "v";
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
