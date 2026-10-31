{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "1.11.1" = {
      builder = ./build-1.11.1.nix;
      base = tvp.bases.default;
      deps = {
        python = tvp.packages.python-build_3;
        bash = tvp.packages.bash_5;
        ninja = tvp.packages.ninja;
        cmake = tvp.packages.cmake;
        pkg-config = tvp.packages.pkg-config;
      };
      patches = [
        {
          file = ./patches/store-rpaths.patch;
          reason = "Store-layout adaptation: retain immutable Nix store library RPATHs during installation; Meson otherwise removes paths added by the owned compiler wrapper and installed shared-library consumers fail to load.";
        }
      ];
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.11.1";
      releases = {
        "1.11.1" = "sha256-Z4iuKZl5ZD+NhBvK9kNSVYQ2yuRaA1UUijruzPeROGY=";
        "1.11.2" = "sha256-aY/q4GnO8+zU16rygdffNZvfz1VamhVkOD07kT+opzY=";
        "1.12.0" = "sha256-iK/gwg5SAwIYkkrDfQyBxZtLXzrjdSyMbXRwx9NliGw=";
        "1.12.1" = "sha256-qwpsoJ+O9wxWTIJB+1ojlXiGoLU/tYQSteB+rwfbp0M=";
      };
    }
  ];
  pname = "meson";
  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      import ./tests {
        inherit tvpLib package;
        zlib = tvp.packages.zlib_1;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
      }
    ) { inherit pkgs; };
    packageMeta.upstream = {
      type = "git-tags";
      url = "https://github.com/mesonbuild/meson.git";
      normalise = tag: tag;
      include = version: builtins.match "[0-9]+(\\.[0-9]+)*" version != null;
    };
  };
in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
