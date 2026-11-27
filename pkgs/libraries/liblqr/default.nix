{ tvp, ... }:
let
  pname = "liblqr";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps.glib = tvp.packages.glib;
      };
      releases."0.4.3" = "sha256-hi/FzsqpbTjU2Secim+/wnY5PwVIkJ7gkS5B31mJRHE=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url =
        version: "https://liblqr.wdfiles.com/local--files/en:download-page/liblqr-1-${version}.tar.bz2";
      discovery = {
        type = "git-tags";
        url = "https://github.com/carlobaldassi/liblqr.git";
        prefix = "v";
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
