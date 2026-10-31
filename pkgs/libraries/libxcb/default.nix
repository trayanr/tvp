{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "1.17.0" = {
      builder = ./build-1.17.0.nix;
      base = tvp.bases.default;
      deps = {
        pkg-config = tvp.packages.pkg-config;
        patchelf = tvp.packages.patchelf;
        python = tvp.packages.python-build_3;
        xcb-proto = tvp.packages.xcb-proto_1;
        libxau = tvp.packages.libxau_1;
        libxdmcp = tvp.packages.libxdmcp_1;
        xorgproto = tvp.packages.xorgproto;
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
