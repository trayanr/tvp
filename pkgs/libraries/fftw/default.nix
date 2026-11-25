{ tvp, ... }:
let
  pname = "fftw";
  versionTable = tvp.lib.packages.mkTable [
    {
      def.builder = ./build.nix;
      releases."3.3.11" = "sha256-VjDCTN6zOxMWEvfrSxqZNCNHVPnziP+GF0WNC+byOaE=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url = version: "https://fftw.org/fftw-${version}.tar.gz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/FFTW/fftw3.git";
        prefix = "fftw-";
        include = version: builtins.match "3\\.[0-9]+\\.[0-9]+" version != null;
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
