{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "1.2.6" = {
      builder = ./build-1.2.6.nix;
      base = tvp.bases.default;
      deps = {
        pkg-config = tvp.packages.pkg-config;
        patchelf = tvp.packages.patchelf;
        libx11 = tvp.packages.libx11_1;
        libxext = tvp.packages.libxext_1;
        libxi = tvp.packages.libxi_1;
        xorgproto = tvp.packages.xorgproto;
        xtrans = tvp.packages.xtrans_1;
        libxcb = tvp.packages.libxcb_1;
        libxau = tvp.packages.libxau_1;
        libxdmcp = tvp.packages.libxdmcp_1;
        libxfixes = tvp.packages.libxfixes_6;
      };
    };
  };
  pname = "libxtst";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.2.6";
      releases."1.2.6" = "sha256-+U8LN8B9gNh38+2iwkBcx+YqqYQvYxA1SqNJ49ZqT+U=";
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
