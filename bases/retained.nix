# Remaining legacy recipe syntax executes on source-owned TVP providers.
# This module does not reconstruct the retired Nixpkgs compiler generations.
{
  lib,
  config,
  builder,
  bases,
  tvpLib,
}:
let
  contexts = {
    gcc_4_9_4 = bases.gcc_4.full;
    gcc_9_5_0 = bases.gcc_9.full;
    gcc_13_3_0 = bases.gcc_13.full;
    gcc_16_2_0 = bases.gcc_16.full;
  };
  canonical = lib.mapAttrs (
    name: base:
    let
      selected = import ./compatibility.nix {
        inherit
          lib
          name
          base
          tvpLib
          ;
        inherit config builder;
        platform = base.platform;
        builtBy = base.construction.previous or null;
      };
    in
    selected
    // {
      tests = import ./tests {
        inherit tvpLib;
        pkgs = {
          inherit lib;
        };
        base = selected;
      };
    }
  ) contexts;
  construction = {
    bases = {
      inherit (canonical) gcc_13_3_0 gcc_16_2_0;
    };
    ownedBases = lib.mapAttrs (_: base: base.ownedBase) construction.bases;
    variants = { };
  };
in
{
  inherit construction;
  legacyBases = canonical // {
    default = canonical.gcc_16_2_0;
  };
}
