# All consumers explicitly select the reconstructed candidate composition.
{
  bootstrap ? import ./. { },
}:
let
  b = bootstrap;
  f = import ./source-native-compiler.nix { inherit bootstrap; };
  inherit (f.composition)
    lib
    base
    bash
    coreutils
    builder
    ;
  make =
    recipe: args:
    builder {
      inherit recipe args;
      dependencyNames = builtins.attrNames args;
      metadata = { };
      selection.kind = "source-native-compiler-test";
      mkTests = _: { };
    };
  fixtures = import ./gnu-environment-fixtures.nix { adapter = f.composition; };
  probeSources = builtins.path {
    name = "tvp-gnu-target-probe-sources";
    path = ./.;
    filter =
      path: type:
      (type == "directory" && path == toString ./.)
      || builtins.elem (baseNameOf path) [
        "gnu-target-maps.h"
        "gnu-target-rtti.h"
        "gnu-target-plugin.cc"
        "gnu-target-rtti.cc"
        "gnu-target-locale.cc"
        "gnu-cancel.c"
        "consumer20.cc"
        "gnu-unwind.cc"
        "gnu-plugin.cc"
      ];
  };
  probe = make (
    { }:
    final: {
      pname = "source-native-gcc-probe";
      version = "1";
      src = null;
      inherit base bash coreutils;
      outputs = [
        "out"
        "evidence"
      ];
      plan = [
        {
          name = "candidate.probe";
          tools = [
            f.tools.python
            b.gnu-binutils
          ];
          run = ''
            export TARGET_LIBC=${f.profile.libc}
            export TARGET_GCC=${f.profile.libgcc}/lib/gcc/x86_64-unknown-linux-gnu/16.2.0
            export TARGET_CXX=${f.profile.libstdcxx}
            export TARGET_CC=${f.driver}/bin/gcc TARGET_CXX_DRIVER=${f.driver}/bin/g++ TARGET_CPP=${f.driver}/bin/cpp
            export TARGET_READELF=${b.gnu-binutils}/bin/readelf
            mkdir -p "$out/bin" "$out/lib" "$evidence"
            ${f.tools.python}/bin/python3 -B ${./gnu-target-checks.py} ${probeSources} "$out" "$evidence" ${f.source}
          '';
        }
      ];
    }
  ) { };
  project = make (
    {
      compilerBase ? base,
    }:
    final: {
      pname = "source-native-gcc-project";
      version = "1";
      src = null;
      base = compilerBase;
      expectedCompiler = final.base.stdenv.cc;
      inherit bash coreutils;
      outputs = [
        "out"
        "evidence"
      ];
      environment = {
        tools = [
          f.tools.make
          f.tools.ninja
          f.tools.cmake
          f.tools.python
        ];
        libraries = [
          f.gmp
          f.mpfr
          f.mpc
        ];
      };
      plan = [
        (
          (final.base.environment final.environment)
          // {
            name = "project.check";
            run = ''
              mkdir -p "$out/bin" "$evidence"
              export EXPECTED_CC=${final.expectedCompiler}/bin/gcc EXPECTED_CXX=${final.expectedCompiler}/bin/g++
                export COMPILER_TRACE_LOG="$evidence/compiler-trace.log"
              export RAW_CC=${f.compiler}/bin/gcc RAW_CXX=${f.compiler}/bin/g++
              export NATIVE_LIBC=${f.profile.libc} NATIVE_GCC=${f.profile.libgcc} NATIVE_CXX=${f.profile.libstdcxx}
              ${f.tools.python}/bin/python3 -B ${./source-native-compiler-checks.py} "$out" "$evidence"
            '';
          }
        )
      ];
    }
  ) { };
  tracePackage = make (
    { }:
    {
      pname = "source-native-compiler-trace";
      version = "1";
      src = null;
      inherit base bash coreutils;
      plan = [
        {
          name = "trace.install";
          run = ''
            mkdir -p "$out/bin"
            for name in cc c++ gcc g++ cpp; do
              cat > "$out/bin/$name" <<TRACE
            #!${bash}/bin/bash
            printf '%s\n' '${f.driver}/bin/'"$name" >> "\$COMPILER_TRACE_LOG"
            exec ${f.driver}/bin/$name "\$@"
            TRACE
              chmod +x "$out/bin/$name"
            done
          '';
        }
      ];
    }
  ) { };
  tracedCompiler = f.driver // {
    outPath = toString tracePackage;
    drvPath = tracePackage.drvPath;
  };
  tracedBase =
    (import ./source-base.nix {
      inherit bootstrap;
      compiler = tracedCompiler;
    }).base;
  constructorRebound = project.override { compilerBase = tracedBase; };
  baseRebound = project.edit (s: s // { base = tracedBase; });
  environmentRebound = project.edit (
    s:
    s
    // {
      expectedCompiler = tracedCompiler;
      environment = s.environment // {
        overrides.values = {
          CC = "${tracedCompiler}/bin/cc";
          CXX = "${tracedCompiler}/bin/c++";
        };
      };
    }
  );
  stepRebound = (project.edit (s: s // { expectedCompiler = tracedCompiler; })).editSteps (
    builder.steps.replace "project.check" (
      s:
      s
      // {
        env = s.env // {
          CC = "${tracedCompiler}/bin/cc";
          CXX = "${tracedCompiler}/bin/c++";
        };
      }
    )
  );
  rebound = import ./source-base.nix {
    inherit bootstrap;
    compiler = f.driver;
  };
  envOf = p: (builtins.head p.buildSteps).env.CC;
  changed = project.override { compilerBase = rebound.base; };
  edited = project.edit (s: s // { base = rebound.base; });
  stepped = project.editSteps (
    builder.steps.replace "project.check" (
      s: s // { run = s.run + ''printf 'step edited\n' > "$out/step-edited"''; }
    )
  );
  # A deliberately unusable compiler proves edits cannot fall back to the old one.
  poisoned = import ./source-base.nix {
    inherit bootstrap;
    compiler = f.driver // {
      outPath = "/candidate-missing-compiler";
    };
  };
in
{
  inherit
    constructorRebound
    baseRebound
    environmentRebound
    stepRebound
    tracePackage
    ;
  inherit
    f
    probe
    project
    stepped
    ;
  supportChecks = f.libbacktrace.override { supportedCheck = true; };
  inherit (fixtures)
    a
    a11
    libraryB
    libraryB11
    consumer
    override
    edited
    customized
    protocol
    ;
  contracts = fixtures.assertions // {
    selected = envOf project == "${f.driver}/bin/cc";
    ordinaryRebinding = envOf changed == "${f.driver}/bin/cc";
    baseEdit = envOf edited == "${f.driver}/bin/cc";
    poisonBase =
      envOf (project.override { compilerBase = poisoned.base; }) == "/candidate-missing-compiler/bin/cc";
    poisonEdit =
      envOf (project.edit (s: s // { base = poisoned.base; })) == "/candidate-missing-compiler/bin/cc";
    environmentEdit =
      envOf (
        project.edit (
          s:
          s
          // {
            environment = s.environment // {
              overrides.values.CC = "/candidate-env-compiler";
            };
          }
        )
      ) == "/candidate-env-compiler";
    stepEdit = stepped.drvPath != project.drvPath;
    inheritedCompiler = f.composition.cc.drvPath == f.driver.drvPath;
    defaultUnchanged =
      (import ./source-base.nix { inherit bootstrap; }).cc.drvPath
      == (import ./gnu-target-driver.nix { inherit bootstrap; }).drvPath;
  };
}
