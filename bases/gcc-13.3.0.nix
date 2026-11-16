# GCC13 is built by the preceding closed source-owned GNU generation.
{
  lib,
  builder,
  platform,
}:
(import ./source-gcc13.nix { inherit lib builder platform; }).family
