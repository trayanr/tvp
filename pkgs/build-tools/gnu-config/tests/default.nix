{
  package,
  lib,
  context,
}:
let
  p = package;
  s = p.specification;
  d = s.base.standardTools // {
    coreutils = s.base.coreutils;
    bash = s.base.shell;
  };
  compiler = s.base.compiler;
  steps = import ../../../../lib/build-steps.nix;
  shell = p.edit (
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
  rebound = p.edit (spec: spec // { base = spec.base.override { inherit shell; }; });
  runtimeRebound = p.editRuntime (r: r // { inherit shell; });
  edited = p.editSteps (
    steps.append [
      {
        name = "gnu-config.output-control";
        run = ''printf edited > "$out/edited"'';
      }
    ]
  );
  alternate = p.edit (
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
context.mkSuite {
  inherit package;
  tools = [
    d.grep
    d.sed
    d.gawk
  ];
  tests = {
    layout = {
      tools = [ d.diffutils ];
      script = ''
        for script in config.guess config.sub; do
          test -x ${p}/$script
          IFS= read -r shebang < ${p}/$script
          test "$shebang" = '#!${p.runtime.shell}/bin/bash'
          test "$(env -i PATH=${d.coreutils}/bin:${d.sed}/bin:${d.grep}/bin:${d.gawk}/bin ${p}/$script --time-stamp)" = '${p.version}'
        done
        cmp ${p.src}/ChangeLog-old ${p}/share/doc/gnu-config/ChangeLog-old
        test "$(cat ${p}/share/doc/gnu-config/revision)" = '${p.tvp.revision}'
        printf layout
      '';
      expected = "layout";
    };
    native = {
      script = ''
        # Log the actual compiler call; Linux libc detection must compile.
        cat > compiler <<SCRIPT
        #!${p.specification.bash}/bin/bash
        printf '%s\n' '${compiler}' >> "$PWD/compiler.log"
        exec ${compiler}/bin/cc "\$@"
        SCRIPT
        chmod +x compiler
        guessed=$(env -i PATH=${d.coreutils}/bin:${d.sed}/bin:${d.grep}/bin:${d.gawk}/bin \
          CC_FOR_BUILD="$PWD/compiler" ${p}/config.guess)
        test -s compiler.log
        test "$(head -1 compiler.log)" = '${compiler}'
        test "$guessed" = x86_64-pc-linux-gnu
        test "$(env -i PATH=${d.coreutils}/bin:${d.sed}/bin:${d.grep}/bin:${d.gawk}/bin ${p}/config.sub "$guessed")" = "$guessed"
        printf '%s' "$guessed"
      '';
      expected = "x86_64-pc-linux-gnu";
      tools = [
        compiler
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
          ((p.mkTests.override { tests = import ./.; }) rebound).layout.drvPath
          == rebound.tests.layout.drvPath;
        assert
          sourceBase.tests.native.specification.base.compiler.drvPath
          == p.tvp.declaredTestDependencies.sentinel.drvPath;
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

// lib.optionalAttrs (package.specification.upstreamCheck.enabled or true) {
  upstream = context.mkUpstream { inherit package; };
}
