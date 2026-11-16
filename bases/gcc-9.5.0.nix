# Complete selected C/C++ profile, built from source on an earlier GNU base.
{
  lib,
  builder,
  platform,
  previous,
}:
let
  source = import ./source-compiler.nix {
    inherit
      lib
      builder
      platform
      previous
      ;
    version = "9.5.0";
    recipe = ../pkgs/compilers/gcc/build-base-9.5.0.nix;
  };
in
{
  inherit (source) full;
}
