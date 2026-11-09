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
        bash = tvp.packages.bash_5;
        bzip2 = tvp.packages.bzip2_1;
        patchelf = tvp.packages.patchelf;
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
  testDeps.unzip = (import ../unzip/legacy.nix { inherit pkgs tvp; }).aliases.unzip;
  publicArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests =
      pkgs.lib.makeOverridable
        (
          { pkgs, unzip }:
          package:
          import ./tests/legacy.nix {
            inherit tvpLib package unzip;
            pkgs = tvpLib.tests.withBase {
              inherit pkgs;
              base.stdenv = package.stdenv;
            };
          }
        )
        {
          inherit pkgs;
          inherit (testDeps) unzip;
        };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
in
{
  recipes.zip = publicArgs;
  inherit publicArgs canonical testDeps;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
