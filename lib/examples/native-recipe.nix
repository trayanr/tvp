# Small authoring example. Direct import evaluates no ordinary catalogue.
{
  candidate ? import ../../bases/source-gnu { },
}:
let
  inherit (candidate)
    lib
    builder
    base
    tools
    ;
  inherit (builder) steps outputs;
  testAPI = import ../tests.nix { inherit lib; };
  source = builtins.toFile "example-answer.c" ''
    #include <stdio.h>
    int main(void) { puts("42"); return 0; }
  '';
  launcher = builtins.toFile "example-launcher.in" ''
    #!@Shell@
    printf '%s\n' @Message@
    exec "@Program@" "$@"
  '';
  package = builder {
    recipe =
      {
        base,
        bash,
        coreutils,
        python,
        src,
      }:
      final: {
        pname = "owned-recipe-example";
        version = "1";
        inherit
          base
          bash
          coreutils
          python
          src
          ;
        outputs = [
          "out"
          "bin"
        ];
        environment = {
          tools = [ ];
          libraries = [ ];
        };
        runtime.message = "answer";
        plan = [
          (
            (final.base.environment final.environment)
            // {
              name = "example.build";
              run = ''"$CC" ${final.src} -o answer'';
            }
          )
          {
            name = "example.install";
            tools = [ final.coreutils ];
            run = ''
              mkdir -p "$out/share" "$bin/bin"
              cp answer "$bin/bin/answer"
              printf '%s\n' ${lib.escapeShellArg final.pname} > "$out/share/name"
            '';
          }
          (steps.split "example.finalize")
          (outputs.copyArtifacts {
            coreutils = final.coreutils;
            outputs = final.outputs;
          })
          (outputs.template {
            python = final.python;
            output = "bin";
            path = "bin/example";
            template = launcher;
            values = {
              Shell = "${final.bash}/bin/bash";
              Message = lib.escapeShellArg final.runtime.message;
              Program = "@OUTPUT@/bin/answer";
            };
          })
        ];
      };
    args = {
      inherit base;
      inherit (tools) bash coreutils python;
      src = source;
    };
    dependencyNames = [
      "bash"
      "coreutils"
      "python"
    ];
    metadata.kind = "documentation-example";
    selection.kind = "documentation-example";
    testContext = package: testAPI.fromPackage { inherit builder package; };
    mkTests =
      package:
      package.testContext.mkSuite {
        inherit package;
        tests = {
          answer = {
            script = ''"${lib.getBin package}/bin/example"'';
            expected = "${package.runtime.message}\n42";
          };
          metadata = {
            tools = [ package.specification.coreutils ];
            script = ''cat ${package}/share/name'';
            expected = package.pname;
          };
        };
      };
  };
  runtimeEdited = package.editRuntime (runtime: runtime // { message = "custom answer"; });
  batch = package.testContext.mkBatch {
    name = "owned-recipe-example";
    suite = package.tests;
  };
in
{
  inherit package runtimeEdited batch;
}
