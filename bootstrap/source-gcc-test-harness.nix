# Independent selected harness; ordinary catalogue and compiler endpoints stay exact.
{
  bootstrap ? import ./. { },
}:
let
  prerequisites = import ./source-full-gcc-prerequisites.nix { inherit bootstrap; };
  inherit (prerequisites) native;
  inherit (native.composition)
    lib
    base
    bash
    coreutils
    builder
    ;
  tools = prerequisites.tools // {
    texinfo = prerequisites.texinfo;
  };
  sources = builtins.mapAttrs (_: import <nix/fetchurl.nix>) (
    builtins.fromJSON (builtins.readFile ./source-gcc-test-harness-sources.json)
  );
  make =
    recipe: args:
    builder {
      inherit recipe args;
      dependencyNames = builtins.attrNames args;
      metadata = { };
      selection.kind = "source-gcc-test-harness";
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
      ;
    inherit (tools) python binutils patchelf;
    buildTools = map (n: tools.${n}) [
      "make"
      "tar"
      "gzip"
      "findutils"
      "sed"
      "grep"
      "gawk"
      "diffutils"
    ];
    gnumake = tools.make;
    gnutar = tools.tar;
    inherit (tools) gzip findutils;
  };
  tcl = make (import ../pkgs/runtimes/tcl/owned/build-8.6.18.nix) (
    common
    // {
      src = sources.tcl;
      zlib = prerequisites.zlib;
      libgcc = native.profile.libgcc;
    }
  );
  expect = make (import ../pkgs/development/expect/owned/build-5.45.4.nix) (
    common
    // {
      src = sources.expect;
      inherit tcl;
    }
  );
  dejagnu = make (import ../pkgs/development/dejagnu/owned/build-1.6.3.nix) (
    common
    // {
      src = sources.dejagnu;
      inherit expect;
    }
  );
  flock = make (import ./recipes/gnu/owned/libgomp-flock.nix) {
    inherit base bash coreutils;
    source = native.source;
    perl = prerequisites.perl;
  };
in
{
  inherit
    prerequisites
    native
    tools
    sources
    tcl
    expect
    dejagnu
    flock
    ;
  composition = native.composition;
}
