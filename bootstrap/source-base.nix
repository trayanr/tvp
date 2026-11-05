# Opt-in base data. Reconstruct with `compiler = ...` to rebind the environment;
# a nested stdenv overlay alone cannot rebind its captured compiler closure.
{
  system ? "x86_64-linux",
  bootstrap ? import ./. { inherit system; },
  compiler ? import ./gnu-target-driver.nix { inherit bootstrap; },
}:
assert system == "x86_64-linux";
let
  lib = import ./owned-lib.nix { inherit system; };
  bash = bootstrap.gnu-bash;
  coreutils = bootstrap.gnu-tool-floor.gnu-coreutils;
  base = {
    name = "source-gnu";
    platform = {
      inherit system;
      config = "x86_64-unknown-linux-gnu";
      isMusl = false;
    };
    stdenv = {
      cc = compiler;
      shell = "${bash}/bin/bash";
      initialPath = [
        bash
        coreutils
      ];
    };
    runtimeDirectories = compiler.runtimeDirectories;
    environment = import ../lib/build-environment.nix { inherit lib base; };
  };
in
{
  inherit
    lib
    base
    bash
    coreutils
    ;
  cc = compiler;
  builder = import ../lib/builder.nix { inherit lib; };
}
