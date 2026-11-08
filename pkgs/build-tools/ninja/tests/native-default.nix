{
  pkgs,
  tvp,
  tvpLib,
  package,
}:
let
  deps = package.tvp.deps;
in
package.testContext.mkSuite {
  inherit package;
  tools = [
    deps.sed
    deps.helperPython
  ];
  tests = {
    jobserver = {
      tools = [
        deps.gnutar
        deps.gzip
      ];
      script = ''
        mkdir source
        tar -xzf ${package.src} --strip-components=1 -C source
        ${package.runtime.python}/bin/python3 ${./native-jobserver.py} ${package}/bin/ninja >&2
        printf scheduling
      '';
      expected = "scheduling";
    };
    version = {
      script = "ninja --version";
      expected = package.version;
    };
    shell = {
      script = ''
        cp ${./fixtures/shell.ninja} build.ninja
        PATH=${package}/bin ninja >&2
        cat answer
      '';
      expected = "42";
    };
    dependencies = {
      script = ''
        cp ${./fixtures/main.cc} main.cc
        cp ${./fixtures/dependencies.ninja} build.ninja
        printf '#define ANSWER 41\n' > answer.h
        ninja >&2
        test "$(./main)" = 41
        printf '#define ANSWER 42\n' > answer.h
        ninja >&2
        test "$(./main)" = 42
        ninja > noop.log
        ${deps.helperPython}/bin/python3 -c 'assert "no work to do" in open("noop.log").read()' 
        ./main
      '';
      expected = "42";
    };
    phases = {
      script = ''
        cp ${./fixtures/build.ninja} build.ninja
        sed -i "s|@out@|$PWD/installed|g" build.ninja
        ninja >&2
        ninja test >&2
        ninja install >&2
        cat installed/answer
      '';
      expected = "42";
    };
    syntax = {
      script = ''
        ${package.runtime.python}/bin/python3 -I -c 'import sys; sys.path.insert(0, "${package}/share/ninja"); import ninja_syntax; assert callable(ninja_syntax.Writer); print("installed")'
      '';
      expected = "installed";
    };
    failure = {
      script = ''
        printf 'rule fail\n  command = exit 23\nbuild broken: fail\n' > build.ninja
        if ninja > failure.log 2>&1; then exit 1; fi
        ${deps.helperPython}/bin/python3 -c 'assert "subcommand failed" in open("failure.log").read(); print("propagated")'
      '';
      expected = "propagated";
    };
    browse = {
      script = ''
        ${package.runtime.python}/bin/python3 ${./native-browse.py} ${package}/bin/ninja
      '';
      expected = "browse";
    };
  };
}

// {
  constructor = import ../../native-frontend-contract.nix { inherit pkgs tvp package; };
}
