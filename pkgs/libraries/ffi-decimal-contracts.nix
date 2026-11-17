# Whole preparation preflight plus actual selected runtime execution through the
# package's complete finalization suffix. The artifact is reused by the latter.
{
  package,
  lib,
  context,
}:
let
  s = package.specification;
  tools = s.base.tools // {
    binutils = s.base.compiler.bintools;
  };
  steps = import ../../lib/build-steps.nix;
  defaultOverride = package.override { cStandard = s.cStandard; };
  library = if package.pname == "libffi" then "libffi.so" else "libmpdec.so";
  copy =
    (builtins.head (builtins.filter (step: step.name == "output.copy-artifacts") package.buildSteps))
    .run
    + "\n"
    + (builtins.head (
      builtins.filter (step: step.name == "${package.pname}.drop-build-tree") package.buildSteps
    )).run;
  suffix =
    (builtins.foldl'
      (acc: step: {
        copied = acc.copied || step.name == "${package.pname}.drop-build-tree";
        steps = acc.steps ++ (if acc.copied then [ step ] else [ ]);
      })
      {
        copied = false;
        steps = [ ];
      }
      package.buildSteps
    ).steps;
  commands = builtins.concatStringsSep "\n" (map (step: step.run or "") suffix);
  testTools = [
    tools.python
    tools.sed
    tools.grep
    tools.gawk
    tools.diffutils
    tools.binutils
  ];
  provider = package.edit (
    spec:
    (builtins.removeAttrs spec [ "artifactName" ])
    // {
      pname = "ffi-decimal-runtime-provider";
      version = "1";
      plan = [
        {
          name = "provider.install";
          run = ''
            mkdir -p "$out/bin"
            cat > "$out/bin/bash" <<'EOF'
            #!${s.base.shell}/bin/bash
            printf 'selected-shell\n' >> "$TVP_PROVIDER_LOG"
            exec ${s.base.shell}/bin/bash "$@"
            EOF
            cat > "$out/bin/probe-provider" <<'EOF'
            #!${s.base.shell}/bin/bash
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
      steps.insertAfter "output.copy-artifacts" [
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
    steps.insertAfter "output.copy-artifacts" [
      (
        (s.base.environment { })
        // {
          name = "contract.loader-spelling";
          tools = [
            tools.patchelf
            s.base.compiler
          ];
          run = ''
            ${tools.patchelf}/bin/patchelf --set-rpath '${spelling}' "$out/${
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
context.mkSuite {
  inherit package;
  tools = testTools;
  tests =
    {
      constructor = {
        expected =
          assert (package.override { }).drvPath == package.drvPath;
          assert (package.edit (spec: spec)).drvPath == package.drvPath;
          assert !(package ? stdenv) && !(package ? overrideAttrs);
          assert
            ((package.mkTests.override { tests = import (./. + "/${package.pname}/tests"); }) package)
            .${if package.pname == "libffi" then "call" else "version"}.package.outPath == package.outPath;
          assert
            (package.edit (
              spec:
              spec // { base = spec.base.override { compiler = package.tvp.declaredTestDependencies.sentinel; }; }
            )).artifact.drvPath != package.artifact.drvPath;
          assert
            (package.override { src = package.tvp.declaredTestDependencies.alternateSource; }).artifact.drvPath
            != package.artifact.drvPath;
          assert package.out.artifact.drvPath == package.artifact.drvPath;
          assert (builtins.head package.all).drvPath == package.drvPath;
          "bound";
        script = "printf bound";
      };
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
      if s.buildFeatures.shared then
        {
          loader-spelling = {
            script = ''
              actual=$(${tools.patchelf}/bin/patchelf --print-rpath ${spelled}/lib/${library})
              expected='${spelling}'
              [[ "$actual" == *"$expected" ]]
              ${spelled}/lib/static-control
              ${tools.binutils}/bin/readelf -h ${spelled}/lib/relocatable.o | grep -F 'REL (Relocatable file)' >&2
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
              ${tools.python}/bin/python3 -B ${./ffi-decimal-safety-tests.py} \
                ${./ffi-decimal-source.py} ${./ffi-decimal-output.py} \
                ${s.bash}/bin/bash ${s.bash}/bin/bash ${tools.binutils}/bin/readelf ${tools.patchelf}/bin/patchelf \
                "$PWD/copy.sh" "$PWD/suffix.sh" ${package.artifact}
            '';
            expected = "ok";
          };
        }
      else
        { }
    );
}
