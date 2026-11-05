# Opt-in BUILD Python and Meson only; the earlier bootstrap Python is unchanged.
{
  bootstrap ? import ./. { },
}:
let
  b = bootstrap;
  prior = import ./source-cmake.nix { inherit bootstrap; };
  inherit (prior.composition)
    lib
    base
    bash
    coreutils
    builder
    ;
  inherit (prior) prerequisites tools;
  sources = builtins.mapAttrs (_: import <nix/fetchurl.nix>) (
    builtins.fromJSON (builtins.readFile ./source-python-meson-sources.json)
  );
  make =
    recipe: args:
    builder {
      inherit recipe args;
      dependencyNames = builtins.attrNames args;
      metadata = { };
      selection.kind = "source-python-meson";
      mkTests = _: { };
    };
  common = {
    inherit
      lib
      base
      bash
      coreutils
      ;
    tvp = {
      inherit builder;
    };
    gnutar = b.gnutar-latest;
    gzip = b.gzip;
    findutils = b.gnu-tool-floor.gnu-findutils;
    patch = b.gnupatch;
  };
  # CPython 3.12.5's OpenSSL4 experiment failed real repeated TLS connections.
  # Keep all existing source4 consumers exact; rebind this consumer only to the
  # existing catalogue's 3.0.21 release, using the same owned source steps.
  pythonOpenssl = prerequisites.openssl.override {
    src = sources.openssl3;
    version = "3.0.21";
  };
  python = make (import ../pkgs/runtimes/python-build/owned/build-3.12.5.nix) (
    common
    // {
      src = sources.python;
      version = "3.12.5";
      python = b.build-python;
      gnumake = b.gnu-tool-floor.gnu-make;
      sed = b.gnused;
      grep = b.build-grep;
      gawk = b.gawk;
      diffutils = b.diffutils;
      inherit (tools) pkgConfig;
      openssl = pythonOpenssl;
      inherit (prerequisites)
        zlib
        bzip2
        xz
        ;
      binutils = b.gnu-binutils;
      patchelf = (import ./output-tool-prerequisites.nix { inherit bootstrap; }).patchelf;
    }
  );
  meson = make (import ../pkgs/build-tools/meson/owned/build-1.12.1.nix) (
    common
    // {
      src = sources.meson;
      version = "1.12.1";
      inherit python;
      helperPython = b.build-python;
      inherit (tools) ninja pkgConfig;
      inherit (prior) cmake;
    }
  );
in
{
  inherit
    prior
    prerequisites
    tools
    sources
    pythonOpenssl
    python
    meson
    ;
  composition = prior.composition;
}
