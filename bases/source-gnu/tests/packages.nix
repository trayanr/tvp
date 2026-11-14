# Focused native qualification, outside the catalogue. Authoritative procedures
# receive explicit definitions; source-shell edits address bootstrap-only hosts.
{
  candidate ? import ../. { },
}:
let
  inherit (candidate) builder base tools;
  lib = candidate.lib // {
    platforms.unix = [ "x86_64-linux" ];
  };
  inherit (builder) steps;
  inherit (tools)
    bash
    coreutils
    python
    binutils
    patchelf
    ;
  sources = builtins.mapAttrs (_: import <nix/fetchurl.nix>) (
    builtins.fromJSON (builtins.readFile ../../../bootstrap/source-consumer-sources.json)
    // {
      json-c =
        (builtins.fromJSON (builtins.readFile ../../../bootstrap/source-cmake-sources.json)).json-c;
    }
  );
  make =
    recipe: args:
    builder {
      inherit recipe args;
      dependencyNames = builtins.attrNames args;
      metadata = { };
      selection.kind = "source-gnu-candidate-test";
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
      python
      binutils
      patchelf
      ;
    gnumake = tools.make;
    gnutar = tools.tar;
  };
  floor = map (n: tools.${n}) [
    "sed"
    "grep"
    "gawk"
    "diffutils"
    "findutils"
  ];
  qualify =
    name: package:
    (package.edit (
      s:
      s
      // {
        environment = s.environment // {
          tools = s.environment.tools ++ floor;
        };
      }
    )).editSteps
      (
        plan:
        let
          unpack = steps.replace "source.unpack" (s: s // { tools = s.tools ++ [ tools.findutils ]; }) plan;
          # Upstream shell scripts refer to /bin/sh or /usr/bin/env. Patch only
          # declared source scripts, never search the host for an interpreter.
          shells =
            if name == "json-c" then
              unpack
            else
              steps.insertAfter "${name}.prepare" [
                (steps.shebangs {
                  name = "${name}.source-shells";
                  inherit python;
                  paths =
                    if name == "gmp" then
                      [
                        "configure"
                        "configfsf.guess"
                        "configfsf.sub"
                        "config.guess"
                        "config.sub"
                        "install-sh"
                        "ltmain.sh"
                        "missing"
                        "test-driver"
                        "compile"
                        "mpn/x86/t-zdisp.sh"
                      ]
                    else if name == "mpc" then
                      [
                        "configure"
                        "build-aux"
                      ]
                    else
                      [
                        "configure"
                        "config.guess"
                        "config.sub"
                        "install-sh"
                        "ltmain.sh"
                        "missing"
                        "depcomp"
                        "test-driver"
                      ];
                  names = [
                    "sh"
                    "bash"
                  ];
                  interpreter = "${bash}/bin/bash";
                })
              ] unpack;
          logged =
            builtins.foldl'
              (
                p: phase:
                steps.replace "${name}.${phase}" (
                  s:
                  s
                  // {
                    run = ''
                      mkdir -p "$out/.qualification"
                      export SHELL=${bash}/bin/bash CONFIG_SHELL=${bash}/bin/bash TVP_SOURCE_ROOT
                      status=0
                      ${bash}/bin/bash -euc ${lib.escapeShellArg s.run} > "$out/.qualification/${phase}.log" 2>&1 || status=$?
                      printf '%s\n' "$status" > "$out/.qualification/${phase}.status"
                      if (( status )); then cat "$out/.qualification/${phase}.log"; exit "$status"; fi
                    '';
                  }
                ) p
              )
              shells
              [
                "configure"
                "build"
                "check"
                "install"
              ];
        in
        steps.insertAfter "output.copy-artifacts" [
          {
            name = "${name}.remove-qualification";
            run = ''rm -rf "$out/.qualification"'';
          }
        ] logged
      );
  # The shared procedures already prepare their sources and retain a compiled
  # checkpoint. Their upstream suites run independently of production A/F.
  gmp = builder {
    recipe = import ../../../pkgs/libraries/gmp/build-6.2.0.nix;
    args = {
      tvp = {
        inherit builder;
      };
      inherit lib base;
      src = sources.gmp;
      version = "6.3.0";
      m4 = tools.m4;
    };
    dependencyNames = [ "m4" ];
    metadata = { };
    selection.kind = "source-gnu-candidate-test";
    testContext =
      package: (import ../../../lib/tests.nix { inherit lib; }).fromPackage { inherit builder package; };
    mkTests =
      package:
      import ../../../pkgs/libraries/gmp/tests/default.nix {
        inherit package lib;
        context = package.testContext;
      };
  };
  mpfr = builder {
    recipe = import ../../../pkgs/libraries/mpfr/build-4.0.2.nix;
    args = {
      tvp = {
        inherit builder;
      };
      inherit lib base gmp;
      src = sources.mpfr;
      version = "4.2.2";
    };
    dependencyNames = [ "gmp" ];
    metadata = { };
    selection.kind = "source-gnu-candidate-test";
    testContext =
      package: (import ../../../lib/tests.nix { inherit lib; }).fromPackage { inherit builder package; };
    mkTests =
      package:
      import ../../../pkgs/libraries/mpfr/tests/default.nix {
        inherit package lib;
        context = package.testContext;
      };
  };
  mpc = builder {
    recipe = import ../../../pkgs/libraries/mpc/build-1.4.0.nix;
    args = {
      tvp = {
        inherit builder;
      };
      inherit
        lib
        base
        gmp
        mpfr
        ;
      src = sources.mpc;
      version = "1.4.1";
    };
    dependencyNames = [
      "gmp"
      "mpfr"
    ];
    metadata = { };
    selection.kind = "source-gnu-candidate-test";
    testContext =
      package: (import ../../../lib/tests.nix { inherit lib; }).fromPackage { inherit builder package; };
    mkTests =
      package:
      import ../../../pkgs/libraries/mpc/tests/default.nix {
        inherit package lib;
        context = package.testContext;
      };
  };
  jsonC = qualify "json-c" (
    make (import ../../../pkgs/libraries/json-c/build-0.19.nix) (
      common
      // {
        src = sources.json-c;
        version = "0.19";
        patches = [ ../../../pkgs/libraries/json-c/patches/posix-test-byte.patch ];
        inherit (tools) cmake gzip patch;
      }
    )
  );
  consumers = make (import ./consumer.nix) {
    inherit
      candidate
      gmp
      mpfr
      mpc
      jsonC
      ;
  };
in
{
  inherit
    candidate
    sources
    gmp
    mpfr
    mpc
    jsonC
    consumers
    ;
}
