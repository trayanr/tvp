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

  construction = import ./gcc13-owned/inputs {
    inherit
      pkgs
      tvpLib
      tvp
      recipes
      ;
  };

  canonical =
    lib.mapAttrs (_: base: base // { tests = import ./tests { inherit pkgs tvpLib base; }; })
      {
        gcc13-owned-v2 = import ./gcc13-owned-v2 {
          inherit pkgs tvp;
          builtBy = construction.bases.gcc13-owned;
          patchelf = construction.variants.gcc13-owned.patchelf_0_19_2;
        };

        gcc9 = mkBase {
          name = "gcc9";
          cc = "9.5.0";
          binutils = "2.42";
          libc = "2.39";
          builtBy = null;
          inherit floor;
          stdenv = withTvpMkDerivation pkgs.gcc9Stdenv;
        };

        # The oldest stdenv nixpkgs offers, and the only one that still accepts
        # cast-as-lvalue.
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
    default = canonical.gcc13-owned-v2;
    gcc13-owned = canonical.gcc13-owned-v2;
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
