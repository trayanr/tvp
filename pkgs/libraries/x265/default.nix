{ tvp, ... }:
let
  pname = "x265";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          git = tvp.packages.git;
          numa = tvp.packages.numactl;
        };
      };
      releases."4.3" = "sha256-g8U+TIu7jx4z7VnhCn1iHR14AcqFORDD60HwOLj/sSE=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url =
        version:
        "https://github.com/Multicorewareinc/x265/releases/download/${version}/x265_${version}.tar.gz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/Multicorewareinc/x265";
        include = version: builtins.match "[0-9]+\\.[0-9]+(\\.[0-9]+)?" version != null;
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
