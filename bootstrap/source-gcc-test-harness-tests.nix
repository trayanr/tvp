{
  bootstrap ? import ./. { },
}:
let
  f = import ./source-gcc-test-harness.nix { inherit bootstrap; };
  inherit (f.composition)
    base
    bash
    coreutils
    builder
    lib
    ;
  make =
    recipe: args:
    builder {
      inherit recipe args;
      dependencyNames = builtins.attrNames args;
      metadata = { };
      selection.kind = "source-gcc-test-harness-tests";
      mkTests = _: { };
    };
  consumer = make (
    { }:
    final: {
      pname = "source-gcc-test-harness-consumers";
      version = "1";
      src = null;
      inherit base bash coreutils;
      outputs = [
        "out"
        "evidence"
      ];
      environment = {
        tools = [
          f.tools.python
          f.tools.pkgConfig
          f.tools.sed
        ];
        libraries = [
          f.tcl
          f.expect
        ];
      };
      plan = [
        (
          (final.base.environment final.environment)
          // {
            name = "harness.consumers";
            run = ''
              mkdir -p "$out/bin" "$evidence"
              export HARNESS=${
                lib.escapeShellArg (
                  builtins.toJSON (
                    builtins.mapAttrs (_: toString) {
                      inherit (f)
                        tcl
                        expect
                        dejagnu
                        flock
                        ;
                      inherit bash coreutils;
                      sed = f.tools.sed;
                      compiler = f.native.driver;
                      gccSource = f.native.source;
                      perl = f.prerequisites.perl;
                      localeTools = f.tools.localeTools;
                    }
                  )
                )
              }
              export FIXTURES=${
                lib.escapeShellArg (
                  builtins.toJSON {
                    eval = ../pkgs/runtimes/tcl/tests/fixtures/eval.tcl;
                    regexp = ../pkgs/runtimes/tcl/tests/fixtures/regexp.tcl;
                    zlib = ../pkgs/runtimes/tcl/tests/fixtures/zlib.tcl;
                  }
                )
              }
              ${f.tools.python}/bin/python3 -B ${./source-gcc-test-harness-checks.py} "$out" "$evidence" ${./source-gcc-test-harness-results.py}
            '';
          }
        )
      ];
    }
  ) { };
in
{
  inherit f consumer;
  upstream = make (
    { }:
    {
      pname = "source-gcc-test-harness-upstream";
      version = "1";
      src = null;
      inherit base bash coreutils;
      plan = [
        {
          name = "harness.upstream";
          tools = [ f.tools.python ];
          run = ''${f.tools.python}/bin/python3 -B ${./source-gcc-test-harness-upstream.py} "$out" ${
            lib.escapeShellArg (
              builtins.toJSON (builtins.mapAttrs (_: p: toString p.evidence) { inherit (f) tcl expect dejagnu; })
            )
          }'';
        }
      ];
    }
  ) { };
  contracts =
    let
      rebound =
        (import ./source-base.nix {
          inherit bootstrap;
          compiler = f.native.driver // {
            outPath = "/missing-compiler";
          };
        }).base;
      configured =
        p: builtins.head (builtins.filter (s: builtins.match ".*\\.configure" s.name != null) p.buildSteps);
      packages = [
        f.tcl
        f.expect
        f.dejagnu
      ];
    in
    {
      constructorBase =
        (configured (f.expect.override { base = rebound; })).env.CC == "/missing-compiler/bin/cc";
      editedBase =
        (configured (f.expect.edit (s: s // { base = rebound; }))).env.CC == "/missing-compiler/bin/cc";
      nativeCompiler = builtins.all (
        p:
        (builtins.head (builtins.filter (s: builtins.match ".*\\.configure" s.name != null) p.buildSteps))
        .env.CC == "${f.native.driver}/bin/cc"
      ) packages;
      environmentReplacement = builtins.all (
        p:
        builtins.all (s: s.env.CC == "/explicit/compiler") (
          builtins.filter (s: builtins.match ".*\\.configure" s.name != null)
            (p.edit (
              s:
              s
              // {
                environment = s.environment // {
                  overrides.values.CC = "/explicit/compiler";
                };
              }
            )).buildSteps
        )
      ) packages;
      cFlagsReplacement = builtins.all (s: s.env.CFLAGS == "-O0 -std=gnu17") (
        builtins.filter (s: builtins.match ".*\\.configure" s.name != null)
          (f.expect.edit (
            s:
            s
            // {
              environment = s.environment // {
                overrides.values.CFLAGS = "-O0 -std=gnu17";
              };
            }
          )).buildSteps
      );
      expectDiscovery =
        (builtins.head (
          builtins.filter (s: builtins.match ".*\\.configure" s.name != null) f.dejagnu.buildSteps
        )).env.TCLLIBPATH == "${f.expect}/lib/expect5.45.4";
      sourceEdit = builtins.all (
        p:
        lib.hasInfix "/replacement/archive"
          (builtins.head (p.edit (s: s // { src = "/replacement/archive"; })).buildSteps).run
      ) packages;
      sourceOverride = (f.expect.override { src = f.sources.tcl; }).drvPath != f.expect.drvPath;
      inputOverride = (f.expect.override { tcl = f.prerequisites.zlib; }).drvPath != f.expect.drvPath;
      stepEdit =
        (f.tcl.editSteps (builder.steps.replace "tcl.build" (s: s // { run = s.run + "\ntrue"; }))).drvPath
        != f.tcl.drvPath;
      publicTcl = builtins.elem f.tcl f.expect.development.libraries;
      publicExpect = builtins.elem f.expect f.dejagnu.development.libraries;
      reused = f.native.driver.drvPath == f.prerequisites.native.driver.drvPath;
    };
}
