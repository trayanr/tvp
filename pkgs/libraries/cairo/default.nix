{ tvp, ... }:
let
  pname = "cairo";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          inherit (tvp.packages)
            fontconfig
            freetype
            glib
            libpng
            libx11
            libxcb
            libxext
            libxrender
            meson
            pixman
            ;
          zlib = tvp.packages.zlib_1;
        };
      };
      releases."1.18.6" = "sha256-HHZzCBdDN6dGlNoPPsBpwnFFIWOh70VAlkxQwwHxV9Q=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url = version: "https://cairographics.org/releases/cairo-${version}.tar.xz";
      discovery = {
        type = "git-tags";
        url = "https://gitlab.freedesktop.org/cairo/cairo.git";
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
