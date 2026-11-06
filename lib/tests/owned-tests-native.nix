# Small opt-in native fixtures. Negative derivations are deliberately not leaves
# of the passing suite; the check exercises their real runner in subprocesses.
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
  packages = import ../../bases/source-gnu/tests/packages.nix { inherit candidate; };
  probes = import ../../bases/source-gnu/tests/probes.nix { inherit candidate; };
  constructors = import ../tests.nix { inherit lib; };
  selected = base.override { compiler = probes.sentinel; };
  tests = constructors.forBase {
    inherit builder;
    base = selected;
    inherit (tools) coreutils;
  };
  package = packages.mpc;
  literal = "quote ' \" $HOME `touch forbidden`\nsecond line";
  source = builtins.toFile "owned-test-consumer.c" ''
    #include <mpc.h>
    #include <stdio.h>
    int main(void) {
      mpc_t x; mpc_init2(x, 128); mpc_set_ui(x, 42, MPC_RNDNN);
      int ok = mpfr_cmp_ui(mpc_realref(x), 42) == 0;
      mpc_clear(x); puts("42"); return !ok;
    }
  '';
  cxxSource = builtins.toFile "owned-test-consumer.cc" ''
    #include <gmpxx.h>
    #include <iostream>
    int main() { mpz_class x = 21; std::cout << x * 2 << std::endl; }
  '';
  observe = binary: ''
    providers=$(${base.compiler.libc}/lib/ld-linux-x86-64.so.2 --list ./${binary})
    printf '%s\n' "$providers" >&2
    [[ "$providers" == *'${base.compiler.libc}/lib/libc.so.6'* ]]
  '';
  suite = tests.mkSuite {
    inherit package;
    tests = {
      command = {
        script = "basename /declared/command";
        expected = "command";
      };
      empty = {
        script = ":";
        expected = "";
      };
      literal = {
        script = "printf '%s\\n' ${lib.escapeShellArg literal}";
        expected = literal;
      };
      newlines = {
        script = "printf 'value\\n\\n\\n'";
        expected = "value";
      };
      c = {
        libraries = [ package ];
        script = ''
          "$CC" ${source} -lmpc -lmpfr -lgmp -o consumer
          test "$(cat selected-compiler)" = selected
          ${observe "consumer"}
          [[ "$providers" == *'${package}/lib/libmpc.so.'* ]]
          [[ "$providers" == *'${packages.mpfr}/lib/libmpfr.so.'* ]]
          [[ "$providers" == *'${packages.gmp}/lib/libgmp.so.'* ]]
          ./consumer
        '';
        expected = "42";
      };
      cxx = {
        libraries = [ packages.gmp ];
        script = ''
          "$CXX" ${cxxSource} -lgmpxx -lgmp -o consumer-cxx
          test "$(cat selected-compiler)" = selected
          ${observe "consumer-cxx"}
          [[ "$providers" == *'${candidate.toolchain.runtime}/lib/libstdc++.so.'* ]]
          ./consumer-cxx
        '';
        expected = "42";
      };
    };
  };
  negativeSpecs = {
    mismatch = {
      script = "printf wrong";
      expected = "right";
      status = 1;
      diagnostic = "expected: right";
    };
    missingOutput = {
      script = ":";
      expected = "right";
      status = 1;
      diagnostic = "expected: right";
    };
    extra = {
      script = "printf 'right extra'";
      expected = "right";
      status = 1;
      diagnostic = "actual:   right extra";
    };
    nonzero = {
      script = "printf right; exit 17";
      expected = "right";
      status = 17;
      diagnostic = "test.compare";
    };
    early = {
      script = "false; printf right";
      expected = "right";
      status = 1;
      diagnostic = "test.compare";
    };
    pipeline = {
      script = "false | cat; printf right";
      expected = "right";
      status = 1;
      diagnostic = "test.compare";
    };
    missing = {
      script = "tvp_deliberately_missing_command; printf right";
      expected = "right";
      status = 127;
      diagnostic = "command not found";
    };
    compiler = {
      script = ''"$CC" ${source} -o forbidden; printf right'';
      expected = "right";
      environment.values.CC = "/missing-owned-test-compiler";
      status = 127;
      diagnostic = "/missing-owned-test-compiler";
    };
    compilerError = {
      script = ''"$CC" -x c /dev/null -o forbidden; printf right'';
      expected = "right";
      status = 1;
      diagnostic = "undefined reference to `main'";
    };
    compilerOverride = {
      script = ''"$CC"; printf right'';
      expected = "right";
      environment.values.CC = "${probes.sentinel}/bin/reject";
      status = 23;
      diagnostic = "deliberate-rejection";
    };
    expectedNewline = {
      script = "printf 'right\\n'";
      expected = "right\n";
      status = 1;
      diagnostic = "FAIL";
    };
  };
  negatives = builtins.mapAttrs (
    name: spec:
    tests.mkTest (
      {
        inherit package name;
      }
      // builtins.removeAttrs spec [
        "status"
        "diagnostic"
      ]
    )
  ) negativeSpecs;
  batch = tests.mkBatch {
    name = "owned-native";
    inherit suite;
  };
  contracts = import ./owned-tests.nix { inherit lib builder; };
  check = builder {
    recipe =
      { }:
      final: {
        pname = "tvp-owned-tests-contracts";
        version = "1";
        src = null;
        inherit base;
        inherit (tools) bash coreutils;
        plan = [
          (
            (final.base.environment {
              libraries = [
                package
                packages.gmp
              ];
            })
            // {
              name = "tests.qualify";
              run = ''
                mkdir "$out"
                ${lib.concatStringsSep "\n" (
                  map (name: ''
                    test "$(readlink ${batch}/${name})" = ${lib.escapeShellArg (toString suite.${name})}
                  '') (builtins.attrNames suite)
                )}
                ${lib.concatStringsSep "\n" (
                  map (
                    name:
                    let
                      spec = negativeSpecs.${name};
                    in
                    ''
                      mkdir ${name}
                      status=0
                      out="$PWD/${name}/result" ${tools.bash}/bin/bash ${
                        negatives.${name}.buildStepRunner.script
                      } "$PWD/${name}" >${name}/stdout 2>${name}/stderr || status=$?
                      test "$status" = ${toString spec.status}
                      diagnostic=$(cat ${name}/stderr)
                      [[ "$diagnostic" == *${lib.escapeShellArg spec.diagnostic}* ]]
                      test ! -e ${name}/result
                      cp ${name}/stdout ${name}/stderr "$out/"
                      mv "$out/stdout" "$out/${name}.stdout"
                      mv "$out/stderr" "$out/${name}.stderr"
                      printf '%s\n' "$status" > "$out/${name}.status"
                    ''
                  ) (builtins.attrNames negatives)
                )}
                printf '%s\n' ${lib.escapeShellArg (builtins.toJSON contracts)} > "$out/contracts.json"
                # Retain two tiny consumers for independent ELF/provider inspection.
                "$CC" ${source} -lmpc -lmpfr -lgmp -o "$out/consumer-c"
                "$CXX" ${cxxSource} -lgmpxx -lgmp -o "$out/consumer-cxx"
                test "$("$out/consumer-c")" = 42
                test "$("$out/consumer-cxx")" = 42
              '';
            }
          )
        ];
      };
    args = { };
    dependencyNames = [ ];
    metadata = { };
    selection.kind = "owned-test-qualification";
    mkTests = _: { };
  };
in
{
  inherit
    suite
    batch
    negatives
    negativeSpecs
    check
    ;
}
