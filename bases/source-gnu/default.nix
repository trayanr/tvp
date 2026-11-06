# Opt-in native base; direct import does not load nixpkgs or the catalogue.
{
  bootstrap ? import ../../bootstrap { },
}:
let
  lib = import ../../bootstrap/owned-lib.nix { system = "x86_64-linux"; };
  builder = import ../../lib/builder.nix { inherit lib; };
  inherit (import ./inputs.nix { inherit bootstrap; }) toolchain tools referencePackages;
  platform = {
    system = "x86_64-linux";
    config = "x86_64-unknown-linux-gnu";
    isMusl = false;
  };
  base = builder.base {
    name = "source-gnu-candidate";
    inherit platform referencePackages;
    compiler = toolchain.driver;
    shell = tools.bash;
    tools = [
      tools.coreutils
      tools.linker
    ];
  };
in
{
  inherit
    lib
    builder
    platform
    base
    toolchain
    tools
    ;
}
