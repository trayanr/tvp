# Opt-in native base; direct import does not load nixpkgs or the catalogue.
{
  bootstrap ? import ../../bootstrap { },
  standardTools ? null,
}:
let
  platform = import ./platform.nix;
  lib = import ../../bootstrap/owned-lib.nix { inherit (platform) system; };
  builder = import ../../lib/builder.nix { inherit lib; };
  inherit (import ./inputs.nix { inherit bootstrap; }) toolchain tools referencePackages;
  base = builder.base {
    name = "source-gnu-candidate";
    inherit platform referencePackages;
    compiler = toolchain.driver;
    shell = tools.bash;
    coreutils = tools.coreutils;
    standardTools =
      if standardTools != null then
        standardTools
      else
        {
          patch = tools.patch;
          gnumake = tools.make;
          gnutar = tools.tar;
          inherit (tools)
            xz
            python
            patchelf
            sed
            grep
            gawk
            diffutils
            findutils
            ;
        };
    tools = [
      tools.coreutils
      tools.linker
    ];
  };
in
{
  withHardening =
    policy:
    import ./hardening {
      candidate = {
        inherit
          base
          builder
          tools
          lib
          ;
      };
      inherit policy;
    };
  inherit
    lib
    builder
    platform
    base
    toolchain
    tools
    ;
}
