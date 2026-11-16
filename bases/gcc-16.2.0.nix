# GCC 16.2.0 reuses the existing compiler generations; stage selection does not build a
# compiler or resolve its prerequisites through the final public catalogue.
{
  lib,
  builder,
  platform,
}:
let
  stages = import ./tiers/source-gnu.nix {
    inherit
      lib
      builder
      platform
      ;
    # These providers belong to the preceding local stage, never final aliases.
    standardTools = import ./source-gnu/standard-tools.nix { tools = stages.native.tools; };
  };
in
{
  inherit (stages) seed full;
  runtime = stages.target;
  reduced = stages.native;
}
