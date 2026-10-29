{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "1.17.0" = {
      builder = ./build-1.17.0.nix;
      base = tvp.bases.default;
      deps = {
        pkg-config = tvp.packages.pkg-config_0_29_2;
        patchelf = tvp.packages.patchelf_0_19_2;
        python = tvp.packages.python-build_3_12_5;
        xcb-proto = tvp.packages.xcb-proto_1_17_0;
        libxau = tvp.packages.libxau_1_0_12;
        libxdmcp = tvp.packages.libxdmcp_1_1_5;
        xorgproto = tvp.packages.xorgproto_2026_1;
      };
    };
  };
  pname = "libxcb";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.17.0";
      releases."1.17.0" = "sha256-WZ6/mZZxD+pxYi5uGE86itW0PQ5fqMTkBxI8iKWabVU=";
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
