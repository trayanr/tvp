{ pkgs, tvp }:
let
  pname = "glib";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          gettext = tvp.packages.gettext;
          libffi = tvp.packages.libffi;
          meson = tvp.packages.meson;
          ninja = tvp.packages.ninja;
          pcre2 = tvp.packages.pcre2;
          python = tvp.packages.python_3;
          zlib = tvp.packages.zlib_1;
        };
      };
      releases."2.88.4" = "sha256-Jf0Wnzsvkf4jka0peIPOD88wxp/Hif/RyWctEzKxxag=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url =
        version:
        "https://download.gnome.org/sources/glib/${pkgs.lib.versions.majorMinor version}/glib-${version}.tar.xz";
      discovery = {
        type = "git-tags";
        url = "https://gitlab.gnome.org/GNOME/glib.git";
        include = version: builtins.match "2\\.[0-9]*[02468]\\.[0-9]+" version != null;
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
