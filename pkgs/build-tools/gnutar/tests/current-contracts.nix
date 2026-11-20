# Whole preparation preflight plus actual selected runtime execution through the
# package's complete finalization suffix. The artifact is reused by the latter.
{
  package,
  lib,
  context,
}:
let
  s = package.specification;
  setup = builtins.concatStringsSep "\n" (
    map (step: step.run) (
      builtins.filter (step: builtins.elem step.name [
        "output.copy-artifacts"
        "gnutar.drop-build-tree"
      ]) package.buildSteps
    )
  );
  suffix =
    (builtins.foldl'
      (acc: step: {
        prepared = acc.prepared || step.name == "gnutar.drop-build-tree";
        steps = acc.steps ++ (if acc.prepared then [ step ] else [ ]);
      })
      {
        prepared = false;
        steps = [ ];
      }
      package.buildSteps
    ).steps;
  commands = builtins.concatStringsSep "\n" (map (step: step.run or "") suffix);
  tools = with package.tvp.declaredDependencies; [
    python
    sed
    grep
    gawk
    diffutils
    binutils
  ];
  provider =
    (context.mkTest {
      inherit package;
      name = "runtime-provider";
      script = ":";
      expected = "";
    }).edit
      (
        old:
        old
        // {
          plan = [
            {
              name = "provider.install";
              run = ''

                mkdir -p "$out/bin"
                cat > "$out/bin/bash" <<'EOF'
                #!${s.bash}/bin/bash
                printf 'selected-shell\n' >> "$TVP_PROVIDER_LOG"
                exec ${s.bash}/bin/bash "$@"
                EOF
                cat > "$out/bin/probe-provider" <<'EOF'
                #!${s.bash}/bin/bash
                printf 'selected-tool\n'
                EOF
                chmod +x "$out/bin/bash" "$out/bin/probe-provider"
              '';
            }
          ];
        }
      );
  runtime =
    (package.editSteps (
      (import ../../../../lib/build-steps.nix).insertAfter "output.copy-artifacts" [
        {
          name = "contract.helper";
          run = ''
            mkdir -p "$out/bin"
            cat > "$out/bin/runtime-probe" <<'EOF'
            #!/bin/sh
            /bin/bash -c 'probe-provider'
            EOF
            chmod +x "$out/bin/runtime-probe"
          '';
        }
      ]
    )).editRuntime
      (
        r:
        r
        // {
          shell = provider;
          tools = [ provider ] ++ r.tools;
        }
      );
  baseLibrary = builtins.head s.base.runtimeDirectories;
  spelling =
    "$ORIGIN/../share:$LIB/../$PLATFORM::\${ORIGIN}/../share:\${LIB}/../\${PLATFORM}:"
    + "${baseLibrary}/\${LIB}/\${PLATFORM}:${baseLibrary}/../lib:";
  spelled = package.editSteps (
    (import ../../../../lib/build-steps.nix).insertAfter "output.copy-artifacts" [
      (
        (s.base.environment { })
        // {
          name = "contract.loader-spelling";
          tools = [
            s.patchelf
            s.base.compiler
          ];
          run = ''
            ${s.patchelf}/bin/patchelf --set-rpath '${spelling}' "$out/bin/tar"
            printf '%s\n' 'int main(void) { return 0; }' > elf-control.c
            "$CC" -c elf-control.c -o "$out/bin/relocatable.o"
            "$CC" -static elf-control.c -o "$out/bin/static-control"
          '';
        }
      )
    ]
  );

in
assert spelled.artifact.drvPath == package.artifact.drvPath;
assert runtime.artifact.drvPath == package.artifact.drvPath;
assert runtime.drvPath != package.drvPath;
context.mkSuite {
  inherit package tools;
  tests = {
    loader-spelling = {
      script = ''
        actual=$(${s.patchelf}/bin/patchelf --print-rpath ${spelled}/bin/tar)
        expected='${spelling}'
        [[ "$actual" == *"$expected" ]]
        ${spelled}/bin/static-control
        ${s.binutils}/bin/readelf -h ${spelled}/bin/relocatable.o | grep -F 'REL (Relocatable file)' >&2
        echo ok
      '';
      expected = "ok";
    };
    confinement = {
      script = ''
        cat > setup.sh <<'TVP_SETUP'
        ${setup}
        TVP_SETUP
        cat > suffix.sh <<'TVP_SUFFIX'
        ${commands}
        TVP_SUFFIX
        ${s.python}/bin/python3 -B ${../ordinary/safety-tests.py} \
          ${../ordinary/source.py} ${../ordinary/output.py} \
          ${s.bash}/bin/bash ${s.perl}/bin/perl ${s.binutils}/bin/readelf ${s.patchelf}/bin/patchelf \
          "$PWD/setup.sh" "$PWD/suffix.sh" ${package.artifact}
      '';
      expected = "ok";
    };
    runtime-provider = {
      script = ''
        ${s.coreutils}/bin/env -i TVP_PROVIDER_LOG="$PWD/provider.log" ${runtime}/bin/runtime-probe
        test "$(wc -l < provider.log)" = 2
        echo ok
      '';
      expected = "selected-tool\nok";
    };
  };
}
