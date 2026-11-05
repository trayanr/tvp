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
  # GNU ld needs link-time lookup for the selected libraries' indirect DSOs
  # under this sysroot. The real linker contributes through the normal tool API.
  linker = compiler.bintools // {
    buildEnvironment =
      context:
      let
        existing = (compiler.bintools.buildEnvironment or (_: { })) context;
        flags = existing.flags or { };
      in
      existing
      // {
        flags = flags // {
          NIX_LDFLAGS =
            (flags.NIX_LDFLAGS or [ ])
            ++ lib.concatMap (
              library:
              lib.concatMap (directory: [
                "-rpath-link"
                directory
              ]) (context.directories library).libraries
            ) context.libraries;
        };
      };
  };
  prepare = import ../lib/build-environment.nix { inherit lib base; };
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
    environment = args: prepare (args // { tools = [ linker ] ++ (args.tools or [ ]); });
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
