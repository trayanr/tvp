# Whole preparation preflight plus actual selected runtime execution through the
# package's complete finalization suffix. The artifact is reused by the latter.
{ tvp, package }:
let
  s = package.specification;
  # Argument overrides and specification edits must describe the same procedure.
  contains = needle: value: builtins.replaceStrings [ needle ] [ "" ] value != value;
  configure =
    p: (builtins.head (builtins.filter (step: step.name == "${p.pname}.configure") p.buildSteps)).run;
  sameBuild = a: b: a.drvPath == b.drvPath && a.artifact.drvPath == b.artifact.drvPath;
  cOverride = package.override { cStandard = "gnu11"; };
  cEdit = package.edit (spec: spec // { cStandard = "gnu11"; });
  defaultOverride = package.override (
    {
      cStandard = s.cStandard;
    }
    // (if package.pname == "ncurses" then { cxxStandard = s.cxxStandard; } else { })
  );
  cxxOverride = package.override { cxxStandard = "gnu++17"; };
  cxxEdit = package.edit (spec: spec // { cxxStandard = "gnu++17"; });
  cxxDefault = package.override { cxxStandard = null; };
  library = if package.pname == "ncurses" then "libncursesw.so.6" else "libreadline.so";
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
        pname = "terminal-runtime-provider";
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
            ${s.patchelf}/bin/patchelf --set-rpath '${spelling}' "$out/lib/${library}"
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
package.testContext.mkSuite {
  inherit package tools;
  tests = {
    dialect-overrides =
      assert sameBuild defaultOverride package;
      assert sameBuild cOverride cEdit;
      assert cOverride.specification.cStandard == "gnu11";
      assert contains "-std=gnu11" (configure cOverride);
      assert
        package.pname != "ncurses"
        || (
          sameBuild cxxOverride cxxEdit
          && cxxOverride.tvp.features.cxxStandard == "gnu++17"
          && contains "-std=gnu++17" (configure cxxOverride)
          && !(contains "export CXXFLAGS=" (configure cxxDefault))
        );
      {
        script = ''
          cat > dialect.c <<'EOF'
          #if __STDC_VERSION__ != 201112L
          #error expected C11
          #endif
          int main(void) { return 0; }
          EOF
          "$CC" -std=${cOverride.specification.cStandard} dialect.c -o dialect
          ./dialect
          ${
            if package.pname == "ncurses" then
              ''
                cat > dialect.cc <<'EOF'
                static_assert(__cplusplus == 201703L, "expected C++17");
                int main() { return 0; }
                EOF
                "$CXX" -std=${cxxOverride.specification.cxxStandard} dialect.cc -o dialect-cxx
                ./dialect-cxx
              ''
            else
              ""
          }
          echo ok
        '';
        expected = "ok";
      };
    loader-spelling = {
      script = ''
        actual=$(${s.patchelf}/bin/patchelf --print-rpath ${spelled}/lib/${library})
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
        cat > copy.sh <<'TVP_COPY'
        ${copy}
        TVP_COPY
        cat > suffix.sh <<'TVP_SUFFIX'
        ${commands}
        TVP_SUFFIX
        ${s.python}/bin/python3 -B ${./safety-tests.py} \
          ${./source.py} ${./output.py} \
          ${s.bash}/bin/bash ${s.perl}/bin/perl ${s.binutils}/bin/readelf ${s.patchelf}/bin/patchelf \
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
