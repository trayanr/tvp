# Whole preparation preflight plus actual selected runtime execution through the
# package's complete finalization suffix. The artifact is reused by the latter.
{ tvp, package }:
let
  s = package.specification;
  defaultOverride = package.override { cStandard = s.cStandard; };
  library = if package.pname == "libffi" then "libffi.so" else "libmpdec.so";
  copy =
    (builtins.head (builtins.filter (step: step.name == "output.copy-artifacts") package.buildSteps))
    .run;
  suffix =
    (builtins.foldl'
      (acc: step: {
        copied = acc.copied || step.name == "output.copy-artifacts";
        steps = acc.steps ++ (if acc.copied then [ step ] else [ ]);
      })
      {
        copied = false;
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
  provider = tvp.builder {
    metadata = { };
    selection.kind = "owned-test-support";
    dependencyNames = [
      "bash"
      "coreutils"
    ];
    mkTests = _: { };
    recipe =
      {
        base,
        bash,
        coreutils,
      }:
      final: {
        pname = "ffi-decimal-runtime-provider";
        version = "1";
        inherit base bash coreutils;
        plan = [
          {
            name = "provider.install";
            run = ''
              mkdir -p "$out/bin"
              cat > "$out/bin/bash" <<'EOF'
              #!${bash}/bin/bash
              printf 'selected-shell\n' >> "$TVP_PROVIDER_LOG"
              exec ${bash}/bin/bash "$@"
              EOF
              cat > "$out/bin/probe-provider" <<'EOF'
              #!${bash}/bin/bash
              printf 'selected-tool\n'
              EOF
              chmod +x "$out/bin/bash" "$out/bin/probe-provider"
            '';
          }
        ];
      };
    args = {
      inherit (s) base bash coreutils;
    };
  };
  runtime =
    (package.editSteps (
      tvp.builder.steps.insertAfter "output.copy-artifacts" [
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
    tvp.builder.steps.insertAfter "output.copy-artifacts" [
      (
        (s.base.environment { })
        // {
          name = "contract.loader-spelling";
          tools = [
            s.patchelf
            s.base.compiler
          ];
          run = ''
            ${s.patchelf}/bin/patchelf --set-rpath '${spelling}' "$out/${
              s.artifactLibraryDirectory or "lib"
            }/${library}"
            mkdir -p "$out/bin" "$out/share"
            printf '%s\n' 'int main(void) { return 0; }' > elf-control.c
            "$CC" -c elf-control.c -o "$out/lib/relocatable.o"
            "$CC" -static elf-control.c -o "$out/lib/static-control"
          '';
        }
      )
    ]
  );

in
assert spelled.artifact.drvPath == package.artifact.drvPath;
assert runtime.artifact.drvPath == package.artifact.drvPath;
assert runtime.drvPath != package.drvPath;
package.testContext.mkSuite {
  inherit package tools;
  tests =
    {
      dialect-overrides =
        assert defaultOverride.drvPath == package.drvPath;
        assert defaultOverride.artifact.drvPath == package.artifact.drvPath;
        {
          script = "echo ok";
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
    }
    // (
      if s.features.shared then
        {
          loader-spelling = {
            script = ''
              actual=$(${s.patchelf}/bin/patchelf --print-rpath ${spelled}/lib/${library})
              expected='${spelling}'
              [[ "$actual" == *"$expected" ]]
              ${spelled}/lib/static-control
              ${s.binutils}/bin/readelf -h ${spelled}/lib/relocatable.o | grep -F 'REL (Relocatable file)' >&2
              echo ok
            '';
            expected = "ok";
          };
          confinement = {
            script = ''
              cat > copy.sh <<'TVP_COPY'
              ${copy}
              TVP_COPY
              cat > suffix.sh <<'TVP_SUFFIX'
              ${commands}
              TVP_SUFFIX
              ${s.python}/bin/python3 -B ${./safety-tests.py} \
                ${./source.py} ${./output.py} \
                ${s.bash}/bin/bash ${s.bash}/bin/bash ${s.binutils}/bin/readelf ${s.patchelf}/bin/patchelf \
                "$PWD/copy.sh" "$PWD/suffix.sh" ${package.artifact}
            '';
            expected = "ok";
          };
        }
      else
        { }
    );
}
