{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "1.8.4" = {
      builder = ./build-1.8.4.nix;
      base = tvp.bases.default;
      deps = {
        pkg-config = tvp.packages.pkg-config;
        patchelf = tvp.packages.patchelf;
        libx11 = tvp.packages.libx11_1;
        libxext = tvp.packages.libxext_1;
        libxfixes = tvp.packages.libxfixes_6;
        xorgproto = tvp.packages.xorgproto;
        xtrans = tvp.packages.xtrans_1;
        libxcb = tvp.packages.libxcb_1;
        libxau = tvp.packages.libxau_1;
        libxdmcp = tvp.packages.libxdmcp_1;
      };
    };
  };
  pname = "libxi";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.8.4";
      releases."1.8.4" = "sha256-3dYFe4mpGQO8L4hNVchGdECQaUXkgsNlRyYN/yhmGvw=";
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
