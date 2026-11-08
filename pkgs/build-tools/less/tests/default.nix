{ package, tvp }:
let
  p = package;
  d = p.tvp.deps;
  upstream = p.editSteps (
    tvp.builder.steps.insertAfter "less.build" [
      (
        (p.specification.base.environment p.specification.environment)
        // {
          name = "less.upstream";
          cwd = "source";
          run = ''
            ${d.gnumake}/bin/make SHELL=${p.specification.bash}/bin/bash LESSTEST=1 LDFLAGS="''${LDFLAGS-} -Wl,--wrap=popen,--wrap=pclose,--wrap=system"
            ${d.gnumake}/bin/make -C lesstest SHELL=${p.specification.bash}/bin/bash CC="$CC" CFLAGS="''${CFLAGS-} -I${d.ncurses}/include/ncursesw"
            (cd lesstest; ${p.tvp.declaredTestDependencies.perl}/bin/perl ./runtest -e -l ../less_t lt) > upstream.log 2>&1 || { cat upstream.log >&2; exit 1; }
            cat upstream.log >&2
            mkdir -p "$out/nix-support/upstream"
            cp upstream.log "$out/nix-support/upstream/"
          '';
        }
      )
    ]
  );
in
p.testContext.mkSuite {
  inherit package;
  tools = [
    d.python
    p.tvp.declaredTestDependencies.diffutils
  ];
  libraries = [ ];
  tests = {
    upstream = {
      script = ''test -s ${upstream}/nix-support/upstream/upstream.log; printf upstream'';
      expected = "upstream";
    };
    version = {
      script = ''${p}/bin/less --version | head -1'';
      expected = "less 710 (PCRE2 regular expressions)";
    };
    commands = {
      script = ''
        test -x ${p}/bin/less-osc8-open; test -x ${p}/bin/lessecho
        ${p}/bin/lessecho 'name with spaces'
      '';
      expected = "name with spaces";
    };
    shell-processes = {
      script = ''
        ${d.python}/bin/python3 -B - <<'PYTHON'
        from pathlib import Path
        text = Path('${../declared-shell.c}').read_text()
        assert text.count('@TVP_SHELL@') == 1
        Path('shell.c').write_text(text.replace('@TVP_SHELL@', '${d.bash}/bin/bash'))
        PYTHON
        "$CC" shell.c ${./declared-shell-test.c} -Wl,--wrap=popen,--wrap=pclose,--wrap=system -o shell-processes
        env -i PATH=/nonexistent ./shell-processes
      '';
      expected = "streams, statuses, signals and reaping";
    };
    declared-shell = {
      script = ''
        printf 'owned pager\n' > 'input with spaces'
        env -i PATH=/nonexistent LESSOPEN='|${d.coreutils}/bin/cat %s' ${p}/bin/less --show-preproc-error 'input with spaces' > actual
        cmp actual 'input with spaces'
        if env -i PATH=/nonexistent LESSOPEN='|${d.bash}/bin/bash -c "printf partial; exit 7" -- %s' ${p}/bin/less --show-preproc-error 'input with spaces' > actual 2> error; then exit 1; fi
        test -s error
        if env -i PATH=/nonexistent ${p}/bin/less missing > actual 2> error; then exit 1; fi
        test -s error
        printf declared
      '';
      expected = "declared";
    };
  };
}
