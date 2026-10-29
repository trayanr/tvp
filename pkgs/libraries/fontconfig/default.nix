{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "2.18.3" = {
      builder = ./build-2.18.3.nix;
      base = tvp.bases.default;
      deps = {
        meson = tvp.packages.meson_1_12_1;
        ninja = tvp.packages.ninja_1_13_2;
        python = tvp.packages.python-build_3_12_5;
        pkg-config = tvp.packages.pkg-config_0_29_2;
        gperf = tvp.packages.gperf_3_3;
        freetype = tvp.packages.freetype_2_15_0;
        expat = tvp.packages.expat_2_9_0;
        patchelf = tvp.packages.patchelf_0_19_2;
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
