{ tvp, ... }:
let
  pname = "pixman";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps.meson = tvp.packages.meson;
      };
      releases."0.46.4" = "sha256-oJjDOSR1StQ/mBt0D21XbHD57RAG4SIhsYRUMevOEjk=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url = version: "https://cairographics.org/releases/pixman-${version}.tar.xz";
      discovery = {
        type = "git-tags";
        url = "https://gitlab.freedesktop.org/pixman/pixman.git";
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
