# Whole preparation preflight plus actual selected runtime execution through the
# package's complete finalization suffix. The artifact is reused by the latter.
{
  package,
  lib,
  context,
}:
let
  s = package.specification;
  tools = s.base.tools;
  binutils = s.base.compiler.bintools;
  support =
    name: run:
    (context.mkTest {
      inherit package name;
      script = ":";
      expected = "";
    }).edit
      (
        test:
        test
        // {
          plan = [
            {
              name = "fixture.${name}";
              inherit run;
            }
          ];
        }
      );
  insert = import ../../lib/build-steps.nix;
  # Argument overrides must remain available on an edited package too. Edits
  # apply after arguments, so supplying its effective dialect is a no-op.
  defaultOverride = package.override (
    {
      cStandard = s.cStandard;
    }
    // (if package.pname == "ncurses" then { cxxStandard = s.cxxStandard; } else { })
  );
  library = if package.pname == "ncurses" then "libncursesw.so.6" else "libreadline.so";
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
        copied = acc.copied || step.name == "output.copy-artifacts";
        steps = acc.steps ++ (if acc.copied then [ step ] else [ ]);
      })
      {
        copied = false;
        steps = [ ];
      }
      package.buildSteps
    ).steps;
  commands = builtins.concatStringsSep "\n" (
    map (step: step.run or "") (
      builtins.filter (step: step.name != "${package.pname}.drop-build-tree") suffix
    )
  );
  commonTools = [
    tools.python
    tools.sed
    tools.grep
    tools.gawk
    tools.diffutils
    binutils
  ];
  provider = support "runtime-provider" ''
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
  runtime =
    (package.editSteps (
      insert.insertAfter "output.copy-artifacts" [
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
    insert.insertAfter "output.copy-artifacts" [
      (
        (s.base.environment { })
        // {
          name = "contract.loader-spelling";
          tools = [
            tools.patchelf
            s.base.compiler
          ];
          run = ''
            ${tools.patchelf}/bin/patchelf --set-rpath '${spelling}' "$out/lib/${library}"
            mkdir -p "$out/bin"
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
  inherit package;
  tools = commonTools;
  tests = {
    dialect-overrides =
      assert defaultOverride.drvPath == package.drvPath;
      assert defaultOverride.artifact.drvPath == package.artifact.drvPath;
      {
        script = "echo ok";
        expected = "ok";
      };
    loader-spelling = {
      script = ''
        actual=$(${tools.patchelf}/bin/patchelf --print-rpath ${spelled}/lib/${library})
        expected='${spelling}'
        [[ "$actual" == *"$expected" ]]
        ${spelled}/bin/static-control
        ${binutils}/bin/readelf -h ${spelled}/bin/relocatable.o | grep -F 'REL (Relocatable file)' >&2
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
        ${tools.python}/bin/python3 -B ${./ncurses/ordinary/safety-tests.py} \
          ${./ncurses/terminal-production-source.py} ${./ncurses/ordinary/output.py} \
          ${s.bash}/bin/bash ${s.perl}/bin/perl ${binutils}/bin/readelf ${tools.patchelf}/bin/patchelf \
          "$PWD/copy.sh" "$PWD/suffix.sh" ${package.artifact}
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
