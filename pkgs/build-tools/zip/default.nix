{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "3.0" = {
      builder = ./build-3.0.nix;
      base = tvp.bases.default;
      # The original Unix probes omit function declarations and return types.
      opts.cflags = "-Wno-error=implicit-function-declaration -Wno-error=implicit-int";
      opts.hardeningDisable = [ "format" ];
      deps = {
        bash = tvp.packages.bash_5_2_37;
        bzip2 = tvp.packages.bzip2_1_0_8;
        patchelf = tvp.packages.patchelf_0_19_2;
      };
    };
  };
  pname = "zip";
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."3.0";
      releases."3.0" = "sha256-8Oi7H5t+sLAShUlaJpnfOkt2Z4TBdlqPGu7fY8CAY2k=";
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
        unzip = tvp.packages.unzip_6_0;
      };
  };
in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
