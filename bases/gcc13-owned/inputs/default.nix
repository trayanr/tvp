# Pinned producer generations used to construct the active owned base.
{
  pkgs,
  tvpLib,
  tvp,
  recipes,
}:
let
  inherit (pkgs) lib;
  inherit (tvpLib.bases) mkBase;
  withTvpMkDerivation =
    stdenv:
    stdenv.override {
      mkDerivationFromStdenv =
        final:
        (import ../../stdenv/make-derivation.nix {
          inherit (pkgs) lib config;
        } final).mkDerivation;
    };
  floor = [
    "coreutils"
    "findutils"
    "diffutils"
    "gnused"
    "gnugrep"
    "gawk"
    "gnutar"
    "gzip"
    "bzip2"
    "gnumake"
    "bash"
    "patch"
    "xz"
    "file"
  ];
  generations = {
    # Not `gcc13Stdenv`: same compiler, different derivation, so it would rebuild
    # every package to no effect.
    gcc13 = mkBase {
      name = "gcc13";
      cc = "13.3.0";
      binutils = "2.42";
      libc = "2.39";
      builtBy = null;
      inherit floor;
      stdenv = withTvpMkDerivation pkgs.stdenv;
    };

    gcc13-owned = import ../. {
      inherit pkgs tvp;
      builtBy = construction.bases.gcc13;
      inputs = construction.variants.gcc13;
    };
  };
  construction = {
    bases = lib.mapAttrs (
      _: base:
      base
      // {
        tests = import ../../tests { inherit pkgs tvpLib base; };
      }
    ) generations;
    variants = tvpLib.packages.mergeVariants {
      build-tools = import ./build-tools.nix {
        inherit
          pkgs
          tvpLib
          recipes
          construction
          ;
      };
      compilers = import ./compilers.nix {
        inherit
          pkgs
          tvpLib
          recipes
          construction
          ;
      };
      libraries = import ./libraries.nix {
        inherit
          pkgs
          tvpLib
          recipes
          construction
          ;
      };
      runtimes = import ./runtimes.nix {
        inherit
          pkgs
          tvpLib
          recipes
          construction
          ;
      };
    };
  };
in
construction
