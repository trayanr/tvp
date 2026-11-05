# Opt-in endpoints only: no canonical producers, aliases, or defaults change.
{
  bootstrap ? import ./. { },
}:
let
  b = bootstrap;
  composition = import ./source-base.nix { inherit bootstrap; };
  inherit (composition)
    lib
    base
    bash
    coreutils
    builder
    ;
  python = b.build-python;
  make =
    recipe: args:
    builder {
      inherit recipe args;
      dependencyNames = builtins.attrNames args;
      metadata = { };
      selection.kind = "source-base-build-tool";
      mkTests = _: { };
    };
  sources = builtins.mapAttrs (_: import <nix/fetchurl.nix>) (
    builtins.fromJSON (builtins.readFile ./source-build-tool-sources.json)
  );
  common = {
    inherit
      lib
      base
      bash
      coreutils
      python
      ;
    tvp = {
      inherit builder;
    };
    gnutar = b.gnutar-latest;
    gzip = b.gzip;
    findutils = b.gnu-tool-floor.gnu-findutils;
    binutils = b.gnu-binutils;
    patchelf = (import ./output-tool-prerequisites.nix { inherit bootstrap; }).patchelf;
  };
  pkgConfig = make (import ../pkgs/build-tools/pkg-config/build-steps-0.29.2.nix) (
    common
    // {
      src = sources.pkg-config;
      version = "0.29.2";
      gnumake = b.gnu-tool-floor.gnu-make;
      sed = b.gnused;
      grep = b.build-grep;
      diffutils = b.diffutils;
      gawk = b.gawk;
    }
  );
  ninja = make (import ../pkgs/build-tools/ninja/build-steps-1.13.2.nix) (
    common
    // {
      src = sources.ninja;
      version = "1.13.2";
      patch = b.gnupatch;
      sed = b.gnused;
    }
  );
  evidenceFor =
    name: package:
    make (
      { }:
      {
        pname = "source-${name}-evidence";
        version = package.version;
        src = null;
        inherit base bash coreutils;
        plan = [
          {
            name = "evidence.collect";
            tools = [ python ];
            run = ''
              cp -a ${package.artifact}/.tvp-evidence "$out"
              chmod -R u+w "$out"
              ${python}/bin/python3 -B ${./source-build-tool-checks.py} ${name} "$out"
            '';
          }
        ];
      }
    ) { };
in
{
  inherit
    composition
    sources
    pkgConfig
    ninja
    ;
  evidence.pkgConfig = evidenceFor "pkg-config" pkgConfig;
  evidence.ninja = evidenceFor "ninja" ninja;
}
