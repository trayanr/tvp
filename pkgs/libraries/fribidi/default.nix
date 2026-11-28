{ tvp, ... }:
let
  pname = "fribidi";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps.meson = tvp.packages.meson;
      };
      releases."1.0.16" = "sha256-GxzeWyNdQEeekb4vDoijCeMhTIq0cOyKJ0TYKlqeoFw=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url =
        version:
        "https://github.com/fribidi/fribidi/releases/download/v${version}/fribidi-${version}.tar.xz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/fribidi/fribidi";
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
