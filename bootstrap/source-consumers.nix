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
  inherit (builder) steps;
  python = b.build-python;
  binutils = b.gnu-binutils;
  patchelf = (import ./output-tool-prerequisites.nix { inherit bootstrap; }).patchelf;
  gnumake = b.gnu-tool-floor.gnu-make;
  findutils = b.gnu-tool-floor.gnu-findutils;
  floor = [
    gnumake
    b.gnused
    b.build-grep
    b.gawk
    b.diffutils
    findutils
  ];
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
      gnumake
      ;
    gnutar = b.gnutar-latest;
    xz = b.xz;
  };
  # Reuse the actual recipes. Every change here is an ordinary spec/step edit.
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
          unpacked = steps.replace "source.unpack" (
            old: old // { tools = lib.unique (old.tools ++ [ findutils ]); }
          ) plan;
          shells = steps.insertAfter "${name}.prepare" [
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
          ] unpacked;
          logged =
            builtins.foldl'
              (
                p: phase:
                steps.replace "${name}.${phase}" (
                  old:
                  old
                  // {
                    run = ''
                      mkdir -p "$out/.tvp-evidence"
                      export SHELL=${bash}/bin/bash CONFIG_SHELL=${bash}/bin/bash TVP_SOURCE_ROOT
                      status=0
                      ${bash}/bin/bash -euc ${lib.escapeShellArg old.run} > "$out/.tvp-evidence/${phase}.log" 2>&1 || status=$?
                      printf '%s\n' "$status" > "$out/.tvp-evidence/${phase}.status"
                      if (( status != 0 )); then cat "$out/.tvp-evidence/${phase}.log"; exit "$status"; fi
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
          captured = steps.insertBefore "${name}.finalize" [
            {
              name = "${name}.capture";
              cwd = "source";
              tools = [ python ];
              run = ''${python}/bin/python3 -B ${./source-suite-evidence.py} capture ${name} "$PWD" "$out/.tvp-evidence"'';
            }
          ] logged;
        in
        steps.insertAfter "output.copy-artifacts" [
          {
            name = "${name}.separate-evidence";
            tools = [ python ];
            run = ''
              rm -rf "$out/.tvp-evidence"
              ${lib.optionalString (name == "gmp") ''
                # Preserve the original diagnostic in the artifact/evidence output.
                # This is the selected command's identity, not a runnable build path.
                ${python}/bin/python3 -B - "$out/include/gmp.h" <<'PY'
                from pathlib import Path
                import re, sys
                p = Path(sys.argv[1])
                data, count = re.subn(r'^#define __GMP_CC .*$', '#define __GMP_CC "cc (TVP capability GNU target GCC 16.2.0)"', p.read_text(), flags=re.M)
                assert count == 1
                p.write_text(data)
                PY
              ''}
            '';
          }
        ] captured
      );
  gmp = qualify "gmp" (
    make (import ../pkgs/libraries/gmp/build-steps-6.3.0.nix) (
      common
      // {
        src = sources.gmp;
        version = "6.3.0";
        inherit findutils;
        m4 = b.build-m4;
      }
    )
  );
  mpfrBase = builder.base {
    name = "source-consumer-mpfr";
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
  mpfr = builder {
    recipe = import ../pkgs/libraries/mpfr/build.nix;
    args = {
      tvp = {
        inherit builder;
      };
      inherit lib gmp;
      base = mpfrBase;
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
  mpc = qualify "mpc" (
    make (import ../pkgs/libraries/mpc/build-steps-1.4.1.nix) (
      common
      // {
        src = sources.mpc;
        version = "1.4.1";
        inherit gmp mpfr;
      }
    )
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
              ${
                if name == "mpfr" then
                  let
                    raw = package.tests.upstream.specification.validation.execution;
                  in
                  ''
                    # Depend on acceptance, then retain its independent raw records.
                    : ${package.tests.upstream}
                    mkdir -p "$out"
                    cp ${raw}/raw/log "$out/check.log"
                    cp ${raw}/raw/status "$out/check.status"
                    cp -r ${raw}/raw/records "$out/upstream"
                  ''
                else
                  ''cp -a ${package.artifact}/.tvp-evidence "$out"''
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
