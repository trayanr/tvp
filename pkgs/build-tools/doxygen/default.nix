{ pkgs, tvp }:
let
  pname = "doxygen";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          inherit (tvp.packages) bison;
          # Flex 2.7.3 mismatches Doxygen's scanner type declarations (westes/flex#895).
          flex = tvp.packages.flex_2_6_4;
          python = tvp.packages.python-build_3;
        };
      };
      releases."1.18.0" = "sha256-od7tcKZ4W77JWisqnkGdx/eyI6nXSoZErmEcji3N01Q=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url =
        version:
        "https://github.com/doxygen/doxygen/releases/download/Release_${
          builtins.replaceStrings [ "." ] [ "_" ] version
        }/doxygen-${version}.src.tar.gz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/doxygen/doxygen";
        normalise =
          tag:
          if builtins.match "Release_[0-9]+_[0-9]+_[0-9]+" tag == null then
            null
          else
            builtins.replaceStrings [ "_" ] [ "." ] (pkgs.lib.removePrefix "Release_" tag);
      };
    };
    tests = import ./tests.nix;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.doxygen = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
