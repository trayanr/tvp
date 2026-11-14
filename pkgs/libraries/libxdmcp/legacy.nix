{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "1.1.5" = {
      builder = ./build-1.1.5.nix;
      base = tvp.bases.default;
      deps = {
        pkg-config = tvp.packages.pkg-config;
        patchelf = tvp.packages.patchelf;
        xorgproto = tvp.packages.xorgproto;
      };
    };
  };
  pname = "libxdmcp";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.1.5";
      releases."1.1.5" = "sha256-2KUiKCjDratwrfaaVYPx0y617OBDBPf4OStqNTqiIow=";
    }
  ];
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      import ./tests {
        inherit tvpLib package;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
      }
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions packageArgs;
in
{
  inherit canonical packageArgs;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
