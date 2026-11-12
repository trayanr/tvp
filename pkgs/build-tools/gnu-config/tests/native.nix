{
  pkgs,
  tvp,
  package,
}:
let
  p = package;
  d = p.tvp.deps;
  steps = tvp.builder.steps;
  shell = d.coreutils.edit (
    s:
    (builtins.removeAttrs s [ "artifactName" ])
    // {
      plan = [
        {
          name = "gnu-config.shell-provider";
          run = ''
            mkdir -p "$out/bin"
            cat > "$out/bin/bash" <<'SCRIPT'
            #!${d.bash}/bin/bash
            if [[ -n "''${TVP_SHELL_LOG-}" ]]; then printf selected >> "$TVP_SHELL_LOG"; fi
            exec ${d.bash}/bin/bash "$@"
            SCRIPT
            chmod +x "$out/bin/bash"
            ln -s bash "$out/bin/sh"
          '';
        }
      ];
    }
  );
  rebound = p.override { bash = shell; };
  runtimeRebound = p.editRuntime (r: r // { bash = shell; });
  edited = p.editSteps (
    steps.append [
      {
        name = "gnu-config.output-control";
        run = ''printf edited > "$out/edited"'';
      }
    ]
  );
  alternate = d.coreutils.edit (
    s:
    (builtins.removeAttrs s [ "artifactName" ])
    // {
      plan = [
        {
          name = "gnu-config.alternate-source";
          run = ''
            cp -R ${p.src} "$out"; chmod -R u+w "$out"
            printf '\nsource override selected\n' >> "$out/ChangeLog-old"
          '';
        }
      ];
    }
  );
  sourceBase = (p.override { src = alternate; }).edit (
    s:
    s
    // {
      base = s.base.override { compiler = p.tvp.declaredTestDependencies.sentinel; };
    }
  );
in
p.testContext.mkSuite {
  inherit package;
  tools = [
    d.grep
    d.sed
    d.gawk
  ];
  tests = {
    layout = {
      tools = [ p.tvp.declaredTestDependencies.diffutils ];
      script = ''
        for script in config.guess config.sub; do
          test -x ${p}/$script
          IFS= read -r shebang < ${p}/$script
          test "$shebang" = '#!${p.runtime.bash}/bin/bash'
          test "$(env -i PATH=${d.coreutils}/bin:${d.sed}/bin:${d.grep}/bin:${d.gawk}/bin ${p}/$script --time-stamp)" = '${p.version}'
        done
        cmp ${p.src}/ChangeLog-old ${p}/share/doc/gnu-config/ChangeLog-old
        test "$(cat ${p}/share/doc/gnu-config/revision)" = '${p.tvp.revision}'
        printf layout
      '';
      expected = "layout";
    };
    upstream = {
      script = ''
          cp -R ${p.src} source
          chmod -R u+w source
          cd source
        cd testsuite
        # The harness generates executable uname/ldd mocks. Bind only their two
        # interpreter directives; keep every assertion and fixture datum intact.
        test "$(${d.grep}/bin/grep -c '^#!/bin/sh$' config-guess.sh)" = 2
        ${d.sed}/bin/sed 's|^#!/bin/sh$|#!${p.specification.bash}/bin/bash|' \
          config-guess.sh > config-guess-selected.sh
        sub=0; guess=0
        ${p.specification.bash}/bin/bash config-sub.sh > config-sub.log 2>&1 || sub=$?
        ${p.specification.bash}/bin/bash config-guess-selected.sh > config-guess.log 2>&1 || guess=$?
        cat config-sub.log config-guess.log >&2
        printf '%s\n' "$sub" > config-sub.exit
        printf '%s\n' "$guess" > config-guess.exit
        printf 'config-sub.sh exit=%s; config-guess.sh exit=%s\n' "$sub" "$guess" >&2
        if (( sub )); then exit "$sub"; fi
        if (( guess )); then exit "$guess"; fi
        for fixture in uname ldd; do
          IFS= read -r interpreter < "$fixture"
          test "$interpreter" = '#!${p.specification.bash}/bin/bash'
          printf '%s: %s\n' "$fixture" "$interpreter"
        done > fixture-interpreters
        printf upstream
      '';
      expected = "upstream";
    };
    native = {
      script = ''
        # Log the actual compiler call; Linux libc detection must compile.
        cat > compiler <<SCRIPT
        #!${p.specification.bash}/bin/bash
        printf '%s\n' '${p.tvp.cc}' >> "$PWD/compiler.log"
        exec ${p.tvp.cc}/bin/cc "\$@"
        SCRIPT
        chmod +x compiler
        guessed=$(env -i PATH=${d.coreutils}/bin:${d.sed}/bin:${d.grep}/bin:${d.gawk}/bin \
          CC_FOR_BUILD="$PWD/compiler" ${p}/config.guess)
        test -s compiler.log
        test "$(head -1 compiler.log)" = '${p.tvp.cc}'
        test "$guessed" = x86_64-pc-linux-gnu
        test "$(env -i PATH=${d.coreutils}/bin:${d.sed}/bin:${d.grep}/bin:${d.gawk}/bin ${p}/config.sub "$guessed")" = "$guessed"
        printf '%s' "$guessed"
      '';
      expected = "x86_64-pc-linux-gnu";
      tools = [
        p.tvp.cc
        d.sed
        d.grep
        d.gawk
      ];
    };
    aliases = {
      script = ''
        test "$(env -i PATH=${d.coreutils}/bin:${d.sed}/bin:${d.grep}/bin:${d.gawk}/bin ${p}/config.sub amd64-linux)" = x86_64-pc-linux-gnu
        test "$(env -i PATH=${d.coreutils}/bin:${d.sed}/bin:${d.grep}/bin:${d.gawk}/bin ${p}/config.sub aarch64-linux-gnu)" = aarch64-unknown-linux-gnu
        test "$(env -i PATH=${d.coreutils}/bin:${d.sed}/bin:${d.grep}/bin:${d.gawk}/bin ${p}/config.sub arm-none-eabi)" = arm-none-eabi
        test "$(env -i PATH=${d.coreutils}/bin:${d.sed}/bin:${d.grep}/bin:${d.gawk}/bin ${p}/config.sub x86_64-w64-mingw32)" = x86_64-w64-mingw32
        if env -i PATH=${d.coreutils}/bin:${d.sed}/bin:${d.grep}/bin:${d.gawk}/bin ${p}/config.sub invalid-tvp-not-a-machine >invalid.out 2>invalid.err; then exit 1; fi
        grep -q 'Invalid configuration' invalid.err
        printf aliases
      '';
      expected = "aliases";
    };
    customization = {
      expected =
        assert (p.override { }).drvPath == p.drvPath;
        assert (p.edit (s: s)).drvPath == p.drvPath;
        assert !(p ? stdenv) && !(p ? overrideAttrs);
        assert rebound.tests.layout.package.outPath == rebound.outPath;
        assert
          ((p.mkTests.override { inherit pkgs; }) rebound).layout.drvPath == rebound.tests.layout.drvPath;
        assert
          sourceBase.tests.native.package.tvp.cc.drvPath == p.tvp.declaredTestDependencies.sentinel.drvPath;
        "customized";
      script = ''
        test "$(cat ${edited}/edited)" = edited
        env -i PATH=${d.coreutils}/bin:${d.sed}/bin:${d.grep}/bin:${d.gawk}/bin TVP_SHELL_LOG="$PWD/shell.log" ${rebound}/config.sub amd64-linux > actual
        test "$(cat actual)" = x86_64-pc-linux-gnu
        test "$(cat shell.log)" = selected
        env -i PATH=${d.coreutils}/bin:${d.sed}/bin TVP_SHELL_LOG="$PWD/runtime-shell.log" ${runtimeRebound}/config.sub arm-none-eabi > runtime-actual
        test "$(cat runtime-actual)" = arm-none-eabi
        test "$(cat runtime-shell.log)" = selected
        test "$(cat ${runtimeRebound.tests.layout})" = layout
        test "$(cat ${rebound.tests.layout})" = layout
        grep -q '^source override selected$' ${sourceBase}/share/doc/gnu-config/ChangeLog-old
        test "$(cat ${sourceBase.tests.native})" = x86_64-pc-linux-gnu
        printf customized
      '';
    };
  };
}
