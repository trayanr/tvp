{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "6.0" = {
      builder = ./build-6.0.nix;
      base = tvp.bases.default;
      # GNU17 preserves main fallthrough semantics in the original Unix probes.
      # Retain their missing-type/declaration warnings and detected features.
      opts.cflags = "-fcommon -std=gnu17 -Wno-error=implicit-int -Wno-error=implicit-function-declaration";
      opts.hardeningDisable = [ "format" ];
      deps = {
        bash = tvp.packages.bash_5;
        patchelf = tvp.packages.patchelf;
      };
    };
  };
  pname = "unzip";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."6.0";
      releases."6.0" = "sha256-A22WmRZG0ESe0KqVLk++IbR2zplKvCduSdMOaGcIvTc=";
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
        zip = tvp.packages.zip;
      };
  };
in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
