# One installed suite for all supported Ninja releases.
{
  package,
  lib,
  context,
}:
let
  s = package.specification;
  tools = s.base.standardTools;
in
context.mkSuite {
  inherit package;
  tools = [
    tools.sed
    tools.python
  ];
  tests = {
    jobserver = {
      tools = [
        tools.gnutar
        tools.gzip
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
        ${tools.python}/bin/python3 -c 'assert "no work to do" in open("noop.log").read()'
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
        ${tools.python}/bin/python3 -c 'assert "subcommand failed" in open("failure.log").read(); print("propagated")'
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
  # Integration adapts the shared fixture to the ordinary family interface.
  constructor = import ../../native-tool-contract.nix { inherit package lib context; };
}

// (context.mkSuite {
  inherit package;
  tools = [ tools.grep ];
  tests = {
    installed-payload = {
      script = ''
        test -s ${package}/share/ninja/ninja_syntax.py
        test -s ${package}/share/doc/ninja/manual.asciidoc
        test -s ${package}/share/licenses/ninja/COPYING
        test -s ${package}/nix-support/setup-hook
        test -s ${package}/nix-support/source-date-epoch
        test ! -x ${package}/share/ninja/ninja_syntax.py
        if head -1 ${package}/share/ninja/ninja_syntax.py | grep -q '^#!'; then exit 1; fi
        printf installed
      '';
      expected = "installed";
    };
    runtime-shell =
      let
        shell = package.tvp.declaredTestDependencies.alternateShell;
        edited = package.editRuntime (runtime: runtime // { inherit shell; });
      in
      {
        tools = [ edited ];
        script =
          assert shell.drvPath != package.runtime.shell.drvPath;
          ''
            cp ${./fixtures/shell.ninja} build.ninja
            env -i PATH=/absent ${edited}/bin/ninja >&2
            cat answer
          '';
        expected = "42";
      };
  };
})
// lib.optionalAttrs (s.upstreamCheck.enabled or true) {
  upstream = import ./upstream.nix { inherit package context; };
}
