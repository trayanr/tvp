{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2.18.3" = {
      builder = ./build-2.18.3.nix;
      base = tvp.bases.default;
      deps = {
        meson = tvp.packages.meson;
        ninja = tvp.packages.ninja;
        python = tvp.packages.python-build_3;
        pkg-config = tvp.packages.pkg-config;
        gperf = tvp.packages.gperf;
        freetype = tvp.packages.freetype_2;
        expat = tvp.packages.expat_2;
        patchelf = tvp.packages.patchelf;
      };
    };
  };
  pname = "fontconfig";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."2.18.3";
      releases."2.18.3" = "sha256-T3tVSjjN94wDP2ZsiHHzdJ4UoJT2Wgf2MMke0LQ9NeM=";
    }
  ];
  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests =
      package:
      import ./tests {
        inherit tvpLib package;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };

      };
  };
in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
