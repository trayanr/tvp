{ package, tvp }:
let
  p = package;
  d = p.tvp.deps;

in
(p.testContext.mkSuite {
  inherit package;
  tools = [
    d.python
    p.tvp.declaredTestDependencies.diffutils
  ];
  libraries = [ ];
  tests = {
    version = {
      script = ''${p}/bin/less --version | head -1'';
      expected = "less 710 (PCRE2 regular expressions)";
    };
    commands = {
      script = ''
        test -x ${p}/bin/less-osc8-open; test -x ${p}/bin/lessecho
        printf 'local file\nwith spaces\n' > 'name with spaces'
        env -i PATH=/nonexistent ${p}/bin/less-osc8-open "file://$PWD/name with spaces" > actual 2> error
        test ! -s error; cmp actual 'name with spaces'
        ${d.python}/bin/python3 -B - <<'PYTHON'
        from pathlib import Path
        path = Path('${p}/bin/less-osc8-open').read_text().splitlines()[1]
        assert path.startswith('PATH=${p}/bin:')
        assert 'tvp-step-' not in path
        PYTHON
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
}) // { upstream = import ./upstream.nix { inherit package; }; }
