# Source-owned generations are composed without looking up public packages.
{
  lib,
  builder,
  bootstrap ? import ../../bootstrap { },
  standardTools ? null,
}:
let
  platform = import ../source-gnu/platform.nix;
  tiers = import ./. { inherit lib builder; };
  initial = import ../../bootstrap/gnu-environment.nix { inherit bootstrap; };
  nativeInputs = import ../../bootstrap/source-native-compiler.nix { inherit bootstrap; };
  outputTools = import ../../bootstrap/output-tool-prerequisites.nix { inherit bootstrap; };
  seedTools = {
    gnumake = bootstrap.gnumake-musl;
    gnutar = bootstrap.gnutar-latest;
    xz = bootstrap.xz;
    gzip = bootstrap.gzip;
    python = bootstrap.build-python;
    patchelf = outputTools.patchelf;
    sed = bootstrap.gnused;
    grep = bootstrap.build-grep;
    gawk = bootstrap.gawk;
    diffutils = bootstrap.diffutils;
    findutils = bootstrap.gnu-tool-floor.gnu-findutils;
  };
  seed = tiers.mkTier {
    name = "source-gnu-seed";
    inherit platform;
    compiler = initial.cc // {
      runtimeDirectories = [
        "${bootstrap.gnu-libc}/lib"
        "${bootstrap.gnu-libgcc}/lib/gcc/x86_64-unknown-linux-gnu/16.2.0"
        "${bootstrap.gnu-libstdcxx}/lib"
      ];
    };
    shell = initial.bash;
    coreutils = initial.coreutils;
    standardTools = seedTools;
    tools = [ bootstrap.gnu-binutils ];
  };
  targetInputs = nativeInputs.prior.composition;
  target = tiers.mkTier {
    name = "source-gnu-target";
    inherit platform;
    previous = seed;
    compiler = targetInputs.cc;
    shell = targetInputs.bash;
    coreutils = targetInputs.coreutils;
    standardTools = seedTools;
    tools = (targetInputs.base.environment { }).tools;
  };
  native = tiers.mkTier {
    name = "source-gnu-native";
    inherit platform;
    previous = target;
    compiler = nativeInputs.driver;
    shell = seed.shell;
    coreutils = seed.coreutils;
    standardTools = seedTools // {
      python = nativeInputs.prior.python;
      gnumake = nativeInputs.tools.make;
    };
    tools = [ nativeInputs.binutils ];
  };
  full = (import ../source-gnu { inherit bootstrap standardTools; }).base.override {
    construction = {
      kind = "stage";
      previous = native.name;
    };
  };
in
{
  inherit
    seed
    target
    native
    full
    ;
}
