{ tvp, ... }:
let
  pname = "imath";
  versionTable = tvp.lib.packages.mkTable [
    {
      def.builder = ./build.nix;
      releases."3.2.3" = "sha256-cvSY5wc4kKKhuHDkU5CKB8lyX50ThFJwQ6OFeL+07zE=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url =
        version:
        "https://github.com/AcademySoftwareFoundation/Imath/releases/download/v${version}/Imath-${version}.tar.gz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/AcademySoftwareFoundation/Imath";
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
