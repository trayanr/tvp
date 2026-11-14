# Adapt an existing provider generation; never select the public base it builds.
{
  lib,
  builder,
  bootstrap ? import ../../bootstrap { },
}:
legacy:
let
  tiers = import ./. { inherit lib builder; };
in
(tiers.fromLegacy legacy).override {
  standardTools = {
    python = bootstrap.build-python;
    patchelf = (import ../../bootstrap/output-tool-prerequisites.nix { inherit bootstrap; }).patchelf;
  };
}
