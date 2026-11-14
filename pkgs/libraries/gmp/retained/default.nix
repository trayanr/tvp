# Frozen construction definitions. Not an alternative ordinary package family.
# Retain until GMP/MPC/ISL inputs can be activated and qualified together (MIG-005).
{
  pkgs,
  tvp,
  versionTable,
  packageMeta,
}:
let
  definitions = tvp.lib.packages.mkDefs {
    "5.0.5" = {
      builder = ./build-5.0.5.nix;
      base = tvp.bases.default;
      deps.m4 = tvp.packages.m4;
      opts.cStandard = "gnu17";
      opts.configureCFlags = [
        "-Wno-error=implicit-int"
        "-Wno-error=implicit-function-declaration"
      ];
    };
    "6.0.0a" = {
      builder = ./build-5.0.5.nix;
      base = tvp.bases.default;
      deps.m4 = tvp.packages.m4;
      opts.cStandard = "gnu17";
      opts.configureCFlags = [
        "-Wno-error=implicit-int"
        "-Wno-error=implicit-function-declaration"
      ];
      opts.reportedVersion = "6.0.0";
      opts.checkCFlags = [ "-Wno-error=implicit-function-declaration" ];
    };
    "6.1.0" = {
      builder = ./build-5.0.5.nix;
      base = tvp.bases.default;
      deps.m4 = tvp.packages.m4;
      opts.cStandard = "gnu17";
    };
  };
in
{
  pname = "gmp";
  inherit packageMeta;
  infra = {
    inherit (pkgs) lib fetchurl;
  };
  versionTable = pkgs.lib.mapAttrs (
    version: entry:
    entry
    // {
      def =
        definitions.${
          if pkgs.lib.versionOlder version "6.0" then
            "5.0.5"
          else if version == "6.0.0a" then
            "6.0.0a"
          else
            "6.1.0"
        };
    }
  ) versionTable;
  extraArgs.mkTests = pkgs.lib.makeOverridable (
    { pkgs }:
    gmp:
    import ../tests/retained.nix {
      inherit gmp;
      tvpLib = tvp.lib;
      pkgs = tvp.lib.tests.withBase {
        inherit pkgs;
        base.stdenv = gmp.stdenv;
      };
    }
  ) { inherit pkgs; };
}
