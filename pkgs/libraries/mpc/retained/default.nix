# Historical construction inputs and tests, pending explicit caller activation.
{
  pkgs,
  tvp,
  versionTable,
  packageMeta,
}:
let
  definitions = tvp.lib.packages.mkDefs {
    "1.0.3" = {
      builder = ./build-1.0.3.nix;
      base = tvp.bases.default;
      deps = {
        gmp = tvp.packages.gmp_6;
        mpfr = tvp.lib.packages.withConstraint {
          reason = "MPC 1.0.3 mul.c defines its own seven-argument mpfr_fmma; MPFR 4 adds a six-argument public function with that name. Native compilation fails with 4.2.2; use the working MPFR 3 line.";
        } tvp.packages.mpfr_3;
      };
    };
    "1.1.0" = {
      builder = ./build-1.0.3.nix;
      base = tvp.bases.default;
      deps = {
        gmp = tvp.packages.gmp_6;
        mpfr = tvp.packages.mpfr_4;
      };
    };
    "1.4.0" = {
      builder = ./build-1.0.3.nix;
      base = tvp.bases.default;
      deps = {
        gmp = tvp.packages.gmp_6;
        mpfr = tvp.packages.mpfr_4;
      };
      opts.archiveExt = "tar.xz";
    };
  };
  retainedDependency = (import ../../mpfr { inherit pkgs tvp; }).instantiate {
    version = "3.1.6";
    base = import ../../../../bases/tiers/construction.nix {
      lib = pkgs.lib;
      builder = tvp.builder;
    } tvp.bases.default;
    deps.gmp = definitions."1.0.3".deps.gmp;
  };
in
{
  pname = "mpc";
  infra = {
    inherit (pkgs) lib fetchurl;
  };
  inherit packageMeta;
  versionTable = pkgs.lib.mapAttrs (
    version: entry:
    entry
    // {
      def =
        if version == "1.0.3" then
          definitions."1.0.3"
          // {
            deps = definitions."1.0.3".deps // {
              mpfr =
                tvp.lib.packages.tagSelection definitions."1.0.3".deps.mpfr.__tvpSelection
                  retainedDependency;
            };
          }
        else if pkgs.lib.versionAtLeast version "1.4.0" then
          definitions."1.4.0"
        else
          definitions."1.1.0";
    }
  ) versionTable;
  extraArgs.mkTests = pkgs.lib.makeOverridable (
    { pkgs }:
    mpc:
    import ../tests/retained.nix {
      inherit mpc;
      tvpLib = tvp.lib;
      pkgs = tvp.lib.tests.withBase {
        inherit pkgs;
        base.stdenv = mpc.stdenv;
      };
    }
  ) { inherit pkgs; };
}
