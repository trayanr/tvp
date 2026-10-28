{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "1.12.1" = {
      builder = ./build-1.12.1.nix;
      base = tvp.bases.default;
      deps = {
        python = tvp.packages.python-build_3_12_5;
        bash = tvp.packages.bash_5_2_37;
        ninja = tvp.packages.ninja_1_13_2;
        cmake = tvp.packages.cmake_4_4_5;
        pkg-config = tvp.packages.pkg-config_0_29_2;
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
      def = defs."1.12.1";
      releases."1.12.1" = "sha256-qwpsoJ+O9wxWTIJB+1ojlXiGoLU/tYQSteB+rwfbp0M=";
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
        zlib = tvp.packages.zlib_1_3_2;
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
