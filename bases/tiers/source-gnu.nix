# Source-owned generations are composed without looking up public packages.
{
  lib,
  builder,
  bootstrap ? import ../../bootstrap { },
  standardTools ? null,
  platform ? import ../source-gnu/platform.nix,
}:
let
  tiers = import ./. { inherit lib builder; };
  initial = import ../../bootstrap/gnu-environment.nix { inherit bootstrap; };
  nativeInputs = import ../../bootstrap/source-native-compiler.nix { inherit bootstrap; };
  outputTools = import ../../bootstrap/output-tool-prerequisites.nix { inherit bootstrap; };
  frontendTools = import ../../bootstrap/source-python-meson.nix { inherit bootstrap; };
  seedTools = {
    gnumake = bootstrap.gnumake-musl;
    gnutar = bootstrap.gnutar-latest;
    xz = bootstrap.xz;
    gzip = bootstrap.gzip;
    bzip2 = bootstrap.bzip2;
    patch = bootstrap.gnupatch;
    python = bootstrap.build-python;
    patchelf = outputTools.patchelf;
    sed = bootstrap.gnused;
    grep = bootstrap.build-grep;
    gawk = bootstrap.gawk;
    diffutils = bootstrap.diffutils;
    findutils = bootstrap.gnu-tool-floor.gnu-findutils;
  };
  seed = tiers.mkStage {
    name = "source-gnu-seed";
    inherit platform;
    tools = seedTools // {
      gcc = initial.cc // {
        runtimeDirectories = [
          "${bootstrap.gnu-libc}/lib"
          "${bootstrap.gnu-libgcc}/lib/gcc/x86_64-unknown-linux-gnu/16.2.0"
          "${bootstrap.gnu-libstdcxx}/lib"
        ];
      };
      bash = initial.bash;
      coreutils = initial.coreutils;
    };
    baselineTools = [ bootstrap.gnu-binutils ];
  };
  targetInputs = nativeInputs.prior.composition;
  target = tiers.mkStage {
    name = "source-gnu-target";
    inherit platform;
    previous = seed;
    tools = seedTools // {
      gcc = targetInputs.cc;
      bash = targetInputs.bash;
      coreutils = targetInputs.coreutils;
    };
    baselineTools = (targetInputs.base.environment { }).tools;
  };
  native = tiers.mkStage {
    name = "source-gnu-native";
    inherit platform;
    previous = target;
    tools = seedTools // {
      gcc = nativeInputs.driver;
      inherit (seed.tools) bash coreutils;
      python = nativeInputs.prior.python;
      gnumake = nativeInputs.tools.make;
      pkg-config = frontendTools.tools.pkgConfig;
      cmake = (import ../../bootstrap/source-cmake.nix { inherit bootstrap; }).cmake;
      ninja = frontendTools.tools.ninja;
      file = (import ../../bootstrap/source-full-gcc.nix { inherit bootstrap; }).file;
      # Exact retained build-host Perl; public Perl may depend on these libraries.
      perl = (import ../../bootstrap/source-cmake-prerequisites.nix { inherit bootstrap; }).perl;
    };
    baselineTools = [ nativeInputs.binutils ];
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
