{
  bootstrap ? import ./. { },
}:
let
  f = import ./source-cmake.nix { inherit bootstrap; };
  b = bootstrap;
  inherit (f.composition)
    lib
    base
    bash
    coreutils
    builder
    cc
    ;
  python = b.build-python;
  binutils = b.gnu-binutils;
  patchelf = (import ./output-tool-prerequisites.nix { inherit bootstrap; }).patchelf;
  make =
    recipe:
    builder {
      inherit recipe;
      args = { };
      dependencyNames = [ ];
      metadata = { };
      selection.kind = "source-cmake-proof";
      mkTests = _: { };
    };
  changed = f.cmake.editRuntime (r: r // { libraries = r.libraries ++ [ f.jsonC ]; });
  changedJson = f.jsonC.editRuntime (r: r // { libraries = [ f.prerequisites.zlib ]; });
  rebound = import ./source-base.nix {
    inherit bootstrap;
    compiler = cc // {
      outPath = "${cc}-constructor-test";
    };
  };
  configured =
    p:
    builtins.head (
      builtins.filter (
        s:
        builtins.elem s.name [
          "cmake.configure"
          "json-c.configure"
        ]
      ) p.buildSteps
    );
  envp =
    p:
    p.edit (
      s:
      s
      // {
        environment = s.environment // {
          overrides.values.OWNED_CALLBACK = "visible";
        };
      }
    );
  basep = p: p.edit (s: s // { base = rebound.base; });
  contracts = {
    cmakeOverride = (f.cmake.override { }).drvPath == f.cmake.drvPath;
    cmakeSteps = (f.cmake.editSteps (s: s)).drvPath == f.cmake.drvPath;
    cmakeRuntimeRebuild = changed.drvPath != f.cmake.drvPath;
    jsonArtifactPreserved = changedJson.artifact.drvPath == f.jsonC.artifact.drvPath;
    jsonRuntimeChanged = changedJson.drvPath != f.jsonC.drvPath;
    cmakeBase = (configured (basep f.cmake)).env.CC == "${cc}-constructor-test/bin/cc";
    jsonBase = (configured (basep f.jsonC)).env.CC == "${cc}-constructor-test/bin/cc";
    cmakeEnvironment = (configured (envp f.cmake)).env.OWNED_CALLBACK == "visible";
    jsonEnvironment = (configured (envp f.jsonC)).env.OWNED_CALLBACK == "visible";
    provider =
      (base.environment {
        tools = [ f.cmake ];
        libraries = [ f.jsonC ];
      }).env.CMAKE_PREFIX_PATH == "${f.jsonC}:${cc.libc}";
    disabled =
      !(builtins.any (s: s.name == "json-c.check") (
        builder.steps.active
          (builder.steps.partition (f.jsonC.override { doCheck = false; }).buildSteps).first
      ));
  };
  consumer = make (
    { }:
    final: {
      pname = "source-cmake-consumer";
      version = "1";
      src = null;
      inherit base bash coreutils;
      outputs = [
        "out"
        "evidence"
      ];
      environment = {
        tools = [
          f.cmake
          f.tools.ninja
          f.tools.pkgConfig
          b.gnu-tool-floor.gnu-make
          python
          b.gnu-tool-floor.gnu-findutils
          b.gnused
          b.build-grep
        ];
        libraries = [
          f.prerequisites.zlib
          f.jsonC
        ];
      };
      runtime.libraries = final.environment.libraries;
      plan = [
        (
          (final.base.environment final.environment)
          // {
            name = "consumer.check";
            tools = (final.base.environment final.environment).tools ++ [
              b.gnutar-latest
              b.gzip
              f.prerequisites.openssl
            ];
            run = ''
              mkdir -p "$out" "$evidence"
              ${python}/bin/python3 -B ${./source-cmake-checks.py} "$out" "$evidence" ${
                lib.escapeShellArg (
                  builtins.toJSON {
                    cmake = "${f.cmake}/bin/cmake";
                    ctest = "${f.cmake}/bin/ctest";
                    cpack = "${f.cmake}/bin/cpack";
                    make = "${b.gnu-tool-floor.gnu-make}/bin/make";
                    ninja = "${f.tools.ninja}/bin/ninja";
                    openssl = "${f.prerequisites.openssl}/bin/openssl";
                    pkgConfig = "${f.tools.pkgConfig}/bin/pkg-config";
                    jsonC = toString f.jsonC;
                    zlib = toString f.prerequisites.zlib;
                    shell = "${bash}/bin/bash";
                    source = f.sources.cmake;
                    fixture = {
                      "CMakeLists.txt" = ../pkgs/build-tools/cmake/tests/fixtures/CMakeLists.txt;
                      "answer.c" = ../pkgs/build-tools/cmake/tests/fixtures/answer.c;
                      "main.cc" = ../pkgs/build-tools/cmake/tests/fixtures/main.cc;
                    };
                    api = ../pkgs/libraries/json-c/tests/fixtures/api.c;
                    inherit contracts;
                  }
                )
              }
            '';
          }
        )
        (builder.outputs.rpaths {
          inherit python binutils patchelf;
          base = final.base;
          paths = [
            "make/bin"
            "make/lib"
            "ninja/bin"
            "ninja/lib"
            "json/bin"
          ];
          libraries = final.runtime.libraries;
        })
        {
          name = "consumer.installed";
          tools = [ python ];
          run = ''${python}/bin/python3 -B ${./source-cmake-checks.py} installed "$out" "$evidence"'';
        }
      ];
    }
  );
  alternate = (import ./source-cmake-prerequisite-tests.nix { inherit bootstrap; }).alternate;
  sourceProbe =
    name: package:
    ((package.override { src = "${alternate}/source.tar.gz"; }).edit (
      s:
      s
      // {
        pname = "source-${name}-override";
        outputs = [ "out" ];
      }
    )).editSteps
      (plan: [
        (builtins.head plan)
        {
          name = "override.verify";
          run = ''
            test "$(cat source/marker)" = 'alternate source'
            mkdir -p "$out"; cp source/marker "$out/"
          '';
        }
      ]);
  sourceOverrideCmake = sourceProbe "cmake" f.cmake;
  sourceOverrideJson = sourceProbe "json-c" f.jsonC;
  runtimeJson = changedJson;

in
assert builtins.all (x: x) (builtins.attrValues contracts);
{
  inherit
    f
    consumer
    contracts
    sourceOverrideCmake
    sourceOverrideJson
    runtimeJson
    ;
}
