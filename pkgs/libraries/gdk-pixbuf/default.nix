{ pkgs, tvp, ... }:
let
  pname = "gdk-pixbuf";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          inherit (tvp.packages)
            glib
            libpng
            libtiff
            meson
            ;
          jpeg = tvp.packages.libjpeg-turbo;
        };
      };
      releases."2.44.8" = "sha256-kZ9SlRKWGhLoHNS0tGakjDkzRp5/mjEMZRPNT7JSujw=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url =
        version:
        "https://download.gnome.org/sources/gdk-pixbuf/${pkgs.lib.versions.majorMinor version}/gdk-pixbuf-${version}.tar.xz";
      discovery = {
        type = "git-tags";
        url = "https://gitlab.gnome.org/GNOME/gdk-pixbuf.git";
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
