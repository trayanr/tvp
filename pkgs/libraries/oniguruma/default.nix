{ tvp, ... }:
let
  pname = "oniguruma";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        # The callback declarations use pre-C23 unprototyped function types.
        opts.cStandard = "gnu17";
      };
      releases."6.9.9" = "sha256-YBYr07n8b0iG1MegeSX/03QWdzL1Xc6MSRv9nNgYps8=";
    }
    {
      def.builder = ./build.nix;
      releases = {
        "6.9.10" = "sha256-Klz8WuJZ5Ol/hraN//wVLNr/6U4gYLdwy4JyONdp/AU=";
      };
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url =
        version: "https://github.com/kkos/oniguruma/releases/download/v${version}/onig-${version}.tar.gz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/kkos/oniguruma.git";
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
