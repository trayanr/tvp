# The ground a package is built on. Derivation-affecting in full: every package
# on a base rebuilds when it changes.
{ pkgs, tvpLib }:
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
          nixpkgsPath = pkgs.path;
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

  canonical = lib.mapAttrs (_: base: base // { tests = import ./tests { inherit tvpLib base; }; }) {
    # Not `gcc13Stdenv`: same compiler, different derivation, so it would rebuild
    # every package to no effect.
    gcc13 = mkBase {
      name = "gcc13";
      cc = "13.3.0";
      builtBy = null;
      inherit floor;
      stdenv = withTvpMkDerivation pkgs.stdenv;
    };

    gcc9 = mkBase {
      name = "gcc9";
      cc = "9.5.0";
      builtBy = null;
      inherit floor;
      stdenv = withTvpMkDerivation pkgs.gcc9Stdenv;
    };

    # The oldest stdenv nixpkgs offers, and the only one that still accepts
    # cast-as-lvalue.
    gcc49 = mkBase {
      name = "gcc49";
      cc = "4.9.4";
      builtBy = null;
      inherit floor;
      stdenv = withTvpMkDerivation pkgs.gcc49Stdenv;
    };
  };

  aliases = {
    default = canonical.gcc13;
  };

  shadowed = lib.intersectLists (lib.attrNames canonical) (lib.attrNames aliases);
in
if shadowed == [ ] then
  canonical // aliases
else
  throw "TVP: base aliases shadow canonical names: ${lib.concatStringsSep ", " shadowed}"
