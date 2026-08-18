# The ground a package is built on, as opposed to the graph it declares.
#
# DERIVATION-AFFECTING IN FULL. Every package built on a base rebuilds when that
# base changes. That is dependencies working correctly, not a flaw — but it is
# why bases are named and versioned rather than edited in place: the blast
# radius of a change is one base, never the repo, exactly as build-VERSION.nix
# scopes a change to one era of one package.
#
# A base is a record, not a bare stdenv, because it will have to carry more than
# a toolchain. Two of TVP's current workarounds are policy rather than version —
# openssl 0.9 needs the `format` hardening off, and php needs PKG_CONFIG_PATH
# named — and both belong to the base rather than to a builder. Keeping the
# record shape from the start means adding those fields later is not an
# interface change.
#
# `stdenv` is the only field consumed today, and it is passed to builders as
# their `stdenv` argument. Builders therefore never mention bases at all: they
# already take `stdenv` and already call `stdenv.mkDerivation`, so swapping a
# base is a substitution rather than an edit. That is what keeps M9 a ladder.
{ pkgs }:
let
  # TVP supplies its own mkDerivation through the seam nixpkgs exposes for it,
  # so the code that computes every TVP derivation is TVP's. Substituting it is
  # derivation-neutral by construction — see ./stdenv/make-derivation.nix.
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

  # Canonical names are immutable, exactly as for packages: `bases.nixpkgs`
  # never changes meaning, so "which base did revision X use" stays answerable.
  canonical = {
    # The seed, named for what it actually is rather than for an era. M9 is
    # finished when no package references it.
    nixpkgs = {
      name = "nixpkgs";
      stdenv = withTvpMkDerivation pkgs.stdenv;
    };

    # Still the nixpkgs seed, with the compiler moved back — named for exactly
    # that, because overclaiming it as an "era" would be false: only the
    # compiler is period, the rest of the environment is current.
    #
    # It exists because gcc's major version reached two digits. Perl's Configure
    # matches the compiler version with the glob `1*`, meaning "gcc 1.x", and
    # every gcc from 10 to 19 matches it too — so 5.28 and earlier build with
    # -fpcc-struct-return and without -fno-strict-aliasing, and miniperl
    # segfaults. gcc 9 reports 9.5.0, takes the correct branch unaided, and the
    # patch TVP would otherwise apply becomes unnecessary.
    nixpkgs-gcc9 = {
      name = "nixpkgs-gcc9";
      stdenv = withTvpMkDerivation pkgs.gcc9Stdenv;
    };
  };

  # Aliases move; canonical names do not.
  aliases = {
    default = canonical.nixpkgs;
  };

  shadowed = pkgs.lib.intersectLists (pkgs.lib.attrNames canonical) (pkgs.lib.attrNames aliases);
in
if shadowed == [ ] then
  canonical // aliases
else
  throw "TVP: base aliases shadow canonical names: ${pkgs.lib.concatStringsSep ", " shadowed}"
