{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "3.3" = {
      builder = ./build-3.3.nix;
      base = tvp.bases.default;
      deps = {
        patchelf = tvp.packages.patchelf_0_19_2;
      };
    };
  };
  pname = "gperf";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."3.3";
      releases."3.3" = "sha256-/Yfgq6fkOuBUg3r9bNTbA6PyaT3rNhkIXm7Z2NlgStg=";
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
