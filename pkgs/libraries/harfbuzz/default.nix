{ tvp, ... }:
let
  pname = "harfbuzz";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          freetype = tvp.packages.freetype;
          glib = tvp.packages.glib;
          icu = tvp.packages.icu;
          meson = tvp.packages.meson;
        };
      };
      releases."12.3.2" = "sha256-b22xZDWaLaWoTvgmYVtEizPmMGBnrYKdhdWwv5NvG7g=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url =
        version:
        "https://github.com/harfbuzz/harfbuzz/releases/download/${version}/harfbuzz-${version}.tar.xz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/harfbuzz/harfbuzz";
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
