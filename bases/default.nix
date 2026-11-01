# The ground a package is built on. Derivation-affecting in full: every package
# on a base rebuilds when it changes.
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
        (import ./stdenv/make-derivation.nix {
          inherit (pkgs) lib config;
        } final).mkDerivation;
    };

  # Asserted against stdenv, not supplied to it: adding a name here fails
  # evaluation rather than putting a tool in the base.
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

  frozen = import ./gcc13-owned/inputs {
    inherit
      pkgs
      tvpLib
      tvp
      recipes
      ;
  };

  construction = frozen // {
    bases = frozen.bases // {
      gcc13-owned-v3 =
        let
          base = import ./gcc13-owned-v3 {
            inherit pkgs tvp;
            builtBy = construction.bases.gcc13-owned;
            previous = construction.bases.gcc13-owned-v2;
            patchelf = construction.variants.gcc13-owned.patchelf_0_19_2;
          };
        in
        base // { tests = import ./tests { inherit pkgs tvpLib base; }; };
    };
    variants = tvpLib.packages.mergeVariants {
      inherit (frozen) variants;
      gcc16 = import ./gcc16-owned/inputs {
        inherit
          pkgs
          tvpLib
          recipes
          construction
          ;
      };
    };
  };

  canonical =
    lib.mapAttrs (_: base: base // { tests = import ./tests { inherit pkgs tvpLib base; }; })
      {
        gcc13-owned-v3 = construction.bases.gcc13-owned-v3;

        gcc16-owned = import ./gcc16-owned {
          inherit pkgs tvp;
          parent = construction.bases.gcc13-owned-v3;
          compiler = construction.variants.gcc16.gcc_16_2_0;
          inputs = construction.variants.gcc16;
        };

        # Retained for broken historical declarations and frozen graph labels.
        # All ordinary buildable GCC9/GCC4.9 consumers use the owned default.
        gcc9 = mkBase {
          name = "gcc9";
          cc = "9.5.0";
          binutils = "2.42";
          libc = "2.39";
          builtBy = null;
          inherit floor;
          stdenv = withTvpMkDerivation pkgs.gcc9Stdenv;
        };

        # Historical broken zlib recipes still name this environment.
        gcc49 = mkBase {
          name = "gcc49";
          cc = "4.9.4";
          binutils = "2.42";
          libc = "2.39";
          builtBy = null;
          inherit floor;
          stdenv = withTvpMkDerivation pkgs.gcc49Stdenv;
        };
      };

  aliases = {
    default = canonical.gcc16-owned;
    gcc16 = canonical.gcc16-owned;
  };

  shadowed = lib.intersectLists (lib.attrNames canonical) (lib.attrNames aliases);
in
if shadowed == [ ] then
  {
    bases = canonical // aliases;
    inherit construction;
  }
else
  throw "TVP: base aliases shadow canonical names: ${lib.concatStringsSep ", " shadowed}"
