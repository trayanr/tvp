{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "1.0.12" = {
      builder = ./build-1.0.12.nix;
      base = tvp.bases.default;
      deps = {
        pkg-config = tvp.packages.pkg-config_0_29_2;
        patchelf = tvp.packages.patchelf_0_19_2;
        xorgproto = tvp.packages.xorgproto_2026_1;
      };
    };
  };
  pname = "libxau";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.0.12";
      releases."1.0.12" = "sha256-dNDk36PTmtiTnpm9o39ZZ6ulKCEQdoKEZNJ3fUd/wPs=";
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
