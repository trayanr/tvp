# Compile a selected historical C/C++ toolchain on an earlier source-owned base.
# Neither the compiler nor the construction tools come from Nixpkgs packages.
{
  lib,
  builder,
  platform,
  version,
  recipe,
  previous,
}:
let
  bootstrap = import ../bootstrap { };
  earlier = import ../bootstrap/source-full-gcc.nix { inherit bootstrap; };
  sources = builtins.fromJSON (builtins.readFile ../pkgs/compilers/gcc/base-sources.json);
  make =
    recipe: args:
    builder {
      inherit recipe args;
      dependencyNames = builtins.filter (name: builtins.isAttrs args.${name} && args.${name} ? drvPath) (
        builtins.attrNames args
      );
      metadata = { };
      selection.kind = "source-base-compiler";
      mkTests = _: { };
    };
  compiler = make (import recipe) {
    inherit lib version;
    tvp = {
      inherit builder;
    };
    base = previous;
    src = import <nix/fetchurl.nix> sources.${version};
    glibc = previous.compiler.libc;
    binutils = previous.compiler.bintools;
    inherit (earlier) file;
    inherit (earlier.prerequisites)
      gmp
      mpfr
      mpc
      zlib
      texinfo
      perl
      which
      ;
  };
  driver = import ../bootstrap/source-full-gcc-driver.nix {
    inherit bootstrap compiler make;
    libc = compiler.libc;
  };
  full = (import ./tiers { inherit lib builder; }).mkStage {
    name = "gcc_${builtins.replaceStrings [ "." ] [ "_" ] version}";
    inherit platform previous;
    tools = (builtins.removeAttrs previous.tools [ "binutils" ]) // {
      gcc = driver;
    };
    baselineTools = previous.baselineTools;
    referencePackages = previous.referencePackages ++ [
      compiler
      driver
      compiler.libc
      compiler.bintools
    ];
  };
in
{
  inherit full compiler driver;
  inherit (compiler) capabilities;
}
