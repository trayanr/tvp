# A separate reduced GNU/GNU/GNU checkpoint. No catalogue/default selection.
{
  bootstrap ? import ./. { },
}:
let
  b = bootstrap;
  prior = import ./source-python-meson.nix { inherit bootstrap; };
  inherit (prior.composition)
    lib
    base
    bash
    coreutils
    builder
    ;
  profile = import ./gnu-target-profile.nix { inherit bootstrap; };
  consumers = import ./source-consumers.nix { inherit bootstrap; };
  sources = builtins.mapAttrs (_: import <nix/fetchurl.nix>) (
    builtins.fromJSON (builtins.readFile ./source-native-compiler-sources.json)
  );
  make =
    recipe: args:
    builder {
      inherit recipe args;
      dependencyNames = builtins.attrNames args;
      metadata = { };
      selection.kind = "source-native-compiler";
      mkTests = _: { };
    };
  common = {
    tvp = {
      inherit builder;
    };
    inherit
      lib
      base
      bash
      coreutils
      profile
      ;
    python = prior.python;
    binutils = b.gnu-binutils;
    gnumake = b.gnu-tool-floor.gnu-make;
    tools = [
      b.gnused
      b.build-grep
      b.gawk
      b.diffutils
      b.gnu-tool-floor.gnu-findutils
    ];
  };
  source = make (import ./recipes/gnu/owned/gcc-source.nix) (
    common
    // {
      inherit sources;
      gnutar = b.gnutar-latest;
      xz = b.xz;
      patch = b.gnupatch;
    }
  );
  libiberty = make (import ./recipes/gnu/owned/gcc-support.nix) (
    common
    // {
      inherit source;
      component = "libiberty";
    }
  );
  libbacktrace = make (import ./recipes/gnu/owned/gcc-support.nix) (
    common
    // {
      inherit source;
      component = "libbacktrace";
    }
  );
  compiler = make (import ./recipes/gnu/owned/gcc.nix) (
    common
    // {
      inherit source libiberty libbacktrace;
      tools = common.tools ++ [
        b.gnutar-latest
        prior.prerequisites.perl
      ];
      inherit (consumers) gmp mpfr mpc;
    }
  );
  driver = import ./source-native-driver.nix {
    inherit
      bootstrap
      compiler
      profile
      make
      ;
  };
in
{
  inherit
    prior
    sources
    source
    libiberty
    libbacktrace
    compiler
    driver
    profile
    ;
  inherit (consumers) gmp mpfr mpc;
  binutils = b.gnu-binutils;
  tools =
    {
      inherit (prior.tools) ninja pkgConfig;
    }
    // {
      inherit (prior) python meson;
      cmake = prior.prior.cmake;
      make = b.gnu-tool-floor.gnu-make;
    };
  # Reconstruct the captured environment closure with the selected compiler.
  composition = import ./source-base.nix {
    inherit bootstrap;
    compiler = driver;
  };
}
