{
  package,
  lib,
  context,
  compression ? "xz",
}:
let
  s = package.specification;
  tools = s.base.tools;
  coreutils = s.base.coreutils;
  bash = s.base.shell;
  binutils = s.base.compiler.bintools;
  codec = if compression == "gzip" then tools.gzip else tools.xz;
  mkSupport =
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
            (
              (s.base.environment {
                tools = [
                  coreutils
                  tools.gnutar
                  codec
                ];
              })
              // {
                name = "fixture.${name}";
                inherit run;
              }
            )
          ];
        }
      );
  archive = mkSupport "source-archive" ''
    mkdir source "$out"
    ${tools.gnutar}/bin/tar -x${
      if compression == "gzip" then "z" else "J"
    }f ${package.src} --strip-components=1 -C source
    chmod -R u+w source
    printf '%s\n' edited-source > source/.tvp-source-marker
    ${tools.gnutar}/bin/tar -c${if compression == "gzip" then "z" else "J"}f "$out/archive" -C source .
  '';
  source =
    (package.edit (spec: (removeAttrs spec [ "artifactName" ]) // { src = "${archive}/archive"; }))
    .editSteps
      (plan: [
        (builtins.head plan)
        {
          name = "source.marker-proof";
          run = ''test "$(cat source/.tvp-source-marker)" = edited-source; cp source/.tvp-source-marker "$out"'';
        }
      ]);
  provider = mkSupport "runtime-provider" ''
    mkdir -p "$out/bin"
    cat > "$out/bin/bash" <<'TVP_SHELL'
    #!${bash}/bin/bash
    printf 'selected-shell\n' >> "$TVP_PROVIDER_LOG"
    exec ${bash}/bin/bash "$@"
    TVP_SHELL
    cat > "$out/bin/probe-provider" <<'TVP_TOOL'
    #!${bash}/bin/bash
    printf 'selected-tool\n'
    TVP_TOOL
    chmod +x "$out/bin/bash" "$out/bin/probe-provider"
  '';
  insert = import ../../lib/build-steps.nix;
  runtime =
    (package.editSteps (
      insert.insertAfter "output.copy-artifacts" [
        {
          name = "contract.helper";
          run = ''
            mkdir -p "$out/bin"
            cat > "$out/bin/runtime-probe" <<'TVP_RUNTIME'
            #!/bin/sh
            /bin/bash -c 'probe-provider'
            TVP_RUNTIME
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
  # The checkpoint is legitimate copy/drop work; fixture snapshots start after
  # that drop, before testing relocation's all-before-write rejection.
  drop = builtins.head (
    builtins.filter (step: step.name == "${package.pname}.drop-build-tree") suffix
  );
  commands = builtins.concatStringsSep "\n" (
    map (step: step.run or "") (builtins.filter (step: step.name != drop.name) suffix)
  );
  commonTools = [
    tools.python
    tools.sed
    tools.grep
    tools.gawk
    tools.diffutils
    binutils
  ];
in
assert runtime.artifact.drvPath == package.artifact.drvPath;
assert runtime.drvPath != package.drvPath;
context.mkSuite {
  inherit package;
  tools = commonTools;
  tests = {
    source-edit = {
      tools = [ source ];
      script = "cat ${source}";
      expected = "edited-source";
    };
    runtime-provider = {
      tools = [ runtime ];
      script = ''
        ${coreutils}/bin/env -i TVP_PROVIDER_LOG="$PWD/provider.log" ${runtime}/bin/runtime-probe
        test "$(wc -l < provider.log)" = 2
        echo ok
      '';
      expected = "selected-tool\nok";
    };
    confinement = {
      tools = commonTools;
      script = ''
        cat > copy.sh <<'TVP_COPY'
        ${copy}
        ${drop.run}
        TVP_COPY
        cat > suffix.sh <<'TVP_SUFFIX'
        ${commands}
        TVP_SUFFIX
        ${tools.python}/bin/python3 -B ${./ordinary-attr-crypt-tests.py} \
          ${./ordinary-attr-crypt-source.py} ${./ordinary-attr-crypt-output.py} \
          ${bash}/bin/bash ${
            if s ? perl then "${s.perl}/bin/perl" else "${package.tvp.declaredTestDependencies.perl}/bin/perl"
          } ${binutils}/bin/readelf ${tools.patchelf}/bin/patchelf \
          "$PWD/copy.sh" "$PWD/suffix.sh" ${package.artifact}
      '';
      expected = "ok";
    };
    source-scopes = {
      tools = commonTools;
      script = ''
        ${tools.python}/bin/python3 -B ${./attr-crypt-source-scopes.py} \
          ${./attr-crypt-production.py} ${./attr-acl-upstream-source.py} ${./attr-crypt-upstream-source.py} ${./compression-source-tree.py} \
          ${bash}/bin/bash ${
            if s ? perl then "${s.perl}/bin/perl" else "${package.tvp.declaredTestDependencies.perl}/bin/perl"
          } >&2
        echo ok
      '';
      expected = "ok";
    };
  };
}
