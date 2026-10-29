{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "1.2.16.1" = {
      builder = ./build-1.2.16.1.nix;
      base = tvp.bases.default;
      deps = {
        patchelf = tvp.packages.patchelf_0_19_2;
      };
    };
  };
  pname = "alsa-lib";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.2.16.1";
      releases."1.2.16.1" = "sha256-90Dbf0iCVZRP/UQoQW7jOQqWdChWkWQz30aMKBQ2SA4=";
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
