{ pkgs, tvp, ... }:
let
  pname = "pango";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          inherit (tvp.packages)
            cairo
            fontconfig
            freetype
            fribidi
            glib
            harfbuzz
            meson
            ;
        };
      };
      releases."1.56.4" = "sha256-FwZeL8xfWlvb/8iEyVa/x8RRqW6MT7L4rYN8ZBPLWgE=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url =
        version:
        "https://download.gnome.org/sources/pango/${pkgs.lib.versions.majorMinor version}/pango-${version}.tar.xz";
      discovery = {
        type = "git-tags";
        url = "https://gitlab.gnome.org/GNOME/pango.git";
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
