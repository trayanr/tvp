{ tvp, ... }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps = {
          pkgConfig = tvp.packages.pkg-config;
          xorgproto = tvp.packages.xorgproto;
        };
      };
      releases = {
        "1.0.10" = "sha256-i+bykjNNL4fluRnAAeFJqf3CcAXWs+BThirG678aDAo=";
        "1.0.11" = "sha256-8/oygvVXDD9r1iAkRDjb+91YD8gPAvVJWHoPirMpu+s=";
        "1.0.12" = "sha256-dNDk36PTmtiTnpm9o39ZZ6ulKCEQdoKEZNJ3fUd/wPs=";
      };
    }
  ];
  pname = "libxau";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.directory {
      url = "https://www.x.org/releases/individual/lib/";
      archive = "libXau-{version}.tar.xz";
    };
    tests = import ./tests/owned.nix;

  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.libxau = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
