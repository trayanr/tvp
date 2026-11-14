# Standalone endpoints, deliberately outside the ordinary catalogue and aliases.
{
  bootstrap ? import ./. { },
}:
let
  b = bootstrap;
  composition = import ./source-base.nix { inherit bootstrap; };
  inherit (composition)
    base
    bash
    coreutils
    builder
    ;
  # MPC's platform list is metadata only; do not enlarge the owned lib surface.
  lib = composition.lib // {
    platforms.unix = [ "x86_64-linux" ];
  };
  python = b.build-python;
  binutils = b.gnu-binutils;
  patchelf = (import ./output-tool-prerequisites.nix { inherit bootstrap; }).patchelf;
  gnumake = b.gnu-tool-floor.gnu-make;
  findutils = b.gnu-tool-floor.gnu-findutils;
  fetch = import <nix/fetchurl.nix>;
  sources = builtins.mapAttrs (_: fetch) (
    builtins.fromJSON (builtins.readFile ./source-consumer-sources.json)
  );
  make =
    recipe: args:
    builder {
      inherit recipe args;
      dependencyNames = builtins.attrNames args;
      metadata = { };
      selection.kind = "source-base-consumer";
      mkTests = _: { };
    };
  libraryBase = builder.base {
    name = "source-consumer-libraries";
    inherit (base) platform;
    compiler = base.stdenv.cc // {
      inherit (base) runtimeDirectories;
    };
    shell = bash;
    inherit coreutils;
    # Preserve the selected linker contribution as well as the baseline providers.
    tools = lib.unique (base.environment { }).tools;
    standardTools = {
      inherit
        gnumake
        python
        patchelf
        findutils
        ;
      gnutar = b.gnutar-latest;
      xz = b.xz;
      gzip = b.gzip;
      sed = b.gnused;
      grep = b.build-grep;
      gawk = b.gawk;
      diffutils = b.diffutils;
    };
    construction = {
      kind = "stage";
      previous = base.name;
    };
  };
  # Complete ordinary procedures, supplied only earlier stage-local inputs.
  gmp =
    (builder {
      recipe = import ../pkgs/libraries/gmp/build-6.2.0.nix;
      args = {
        tvp = {
          inherit builder;
        };
        inherit lib;
        base = libraryBase;
        src = sources.gmp;
        version = "6.3.0";
        m4 = b.build-m4;
      };
      dependencyNames = [ "m4" ];
      metadata = { };
      selection.kind = "source-base-consumer";
      testContext =
        package: (import ../lib/tests.nix { inherit lib; }).fromPackage { inherit builder package; };
      mkTests =
        package:
        import ../pkgs/libraries/gmp/tests {
          inherit package lib;
          context = package.testContext;
        };
    }).editSteps
      (
        plan:
        plan
        ++ [
          {
            name = "gmp.header-compiler-identity";
            tools = [ python ];
            run = ''
              # This macro is a diagnostic label, not a runnable compiler reference.
              # The original configured header remains in A's compiled checkpoint.
              ${python}/bin/python3 -B - "$out/include/gmp.h" <<'PYTHON'
              from pathlib import Path
              import re, sys
              p = Path(sys.argv[1])
              data, count = re.subn(r'^#define __GMP_CC .*$', '#define __GMP_CC "cc (TVP capability GNU target GCC 16.2.0)"', p.read_text(), flags=re.M)
              assert count == 1
              p.write_text(data)
              PYTHON
            '';
          }
        ]
      );
  mpfr = builder {
    recipe = import ../pkgs/libraries/mpfr/build-4.0.2.nix;
    args = {
      tvp = {
        inherit builder;
      };
      inherit lib gmp;
      base = libraryBase;
      src = sources.mpfr;
      version = "4.2.2";
    };
    dependencyNames = [ "gmp" ];
    metadata = { };
    selection.kind = "source-base-consumer";
    testContext =
      package: (import ../lib/tests.nix { inherit lib; }).fromPackage { inherit builder package; };
    mkTests =
      package:
      import ../pkgs/libraries/mpfr/tests/default.nix {
        inherit package lib;
        context = package.testContext;
      };
  };
  mpc = builder {
    recipe = import ../pkgs/libraries/mpc/build-1.4.0.nix;
    args = {
      tvp = {
        inherit builder;
      };
      inherit lib gmp mpfr;
      base = libraryBase;
      src = sources.mpc;
      version = "1.4.1";
    };
    dependencyNames = [
      "gmp"
      "mpfr"
    ];
    metadata = { };
    selection.kind = "source-base-consumer";
    testContext =
      package: (import ../lib/tests.nix { inherit lib; }).fromPackage { inherit builder package; };
    mkTests =
      package:
      import ../pkgs/libraries/mpc/tests {
        inherit package lib;
        context = package.testContext;
      };
  };
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
              ${
                let
                  raw = package.tests.upstream.specification.validation.execution;
                in
                ''
                  # Depend on acceptance, then retain independent raw records.
                  : ${package.tests.upstream}
                  mkdir -p "$out"
                  cp ${raw}/raw/log "$out/check.log"
                  cp ${raw}/raw/status "$out/check.status"
                  cp -r ${raw}/raw/records "$out/upstream"
                ''
              }
              chmod -R u+w "$out"
              ${python}/bin/python3 -B ${./source-suite-evidence.py} classify ${name} "$out"
              ${python}/bin/python3 -B ${./source-suite-checks.py} ${name} "$out"
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
    gmp
    mpfr
    mpc
    ;
  evidence = {
    gmp = evidenceFor "gmp" gmp;
    # Upstream is now independent of the production artifact/final pair.
    mpfr = evidenceFor "mpfr" mpfr;
    mpc = evidenceFor "mpc" mpc;
  };
}
