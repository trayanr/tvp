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
    tools =
      {
        gcc = toolchain.driver;
        inherit (tools) bash coreutils;
      }
      // (
        if standardTools != null then
          standardTools
        else
          {
            bzip2 = tools.bzip2;
            patch = tools.patch;
            pkg-config = tools.pkgConfig;
            gnumake = tools.make;
            gnutar = tools.tar;
            inherit (tools)
              file
              cmake
              ninja
              perl
              xz
              gzip
              python
              patchelf
              sed
              grep
              gawk
              diffutils
              findutils
              ;
          }
      );
    baselineTools = [
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
