{ pkgs, tvp, ... }:
let
  pname = "librsvg";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          inherit (tvp.packages)
            cairo
            freetype
            gdk-pixbuf
            glib
            harfbuzz
            pango
            ;
          libxml2 = tvp.packages.libxml2_2;
          rustc = tvp.packages.rustc_1;
          cargo = tvp.packages.cargo-bootstrap_1;
        };
        opts.cargoLock = ./Cargo-2.58.5.lock;
      };
      releases."2.58.5" = "sha256-IkIzoONH04xBXxWknw4IhTE+PswY8xkgVfkwTdLzono=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url =
        version:
        "https://download.gnome.org/sources/librsvg/${pkgs.lib.versions.majorMinor version}/librsvg-${version}.tar.xz";
      discovery = {
        type = "git-tags";
        url = "https://gitlab.gnome.org/GNOME/librsvg.git";
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
