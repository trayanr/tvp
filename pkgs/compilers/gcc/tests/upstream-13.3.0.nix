# R and U are independent factory products; neither is a production input.
{
  package,
  tvp,
  lib,
}:
let
  s = package.specification;
  libc = s.glibc;
  shell = "${s.bash}/bin/bash";
  includes = s.libcFlags;
  links = builtins.replaceStrings [ "$out" ] [ (toString package.artifact) ] s.linkFlags;
  flags = ""; # flags are restored verbatim from production stage-flags.txt.
  execution = tvp.builder {
    recipe =
      { }:
      _: {
        pname = "gcc-upstream-execution";
        inherit (s)
          version
          base
          bash
          coreutils
          ;
        src = null;
        validationRole = "upstream-execution";
        plan = [
          (
            (s.base.environment (
              s.environment
              // {
                tools = s.environment.tools ++ [
                  s.dejagnu
                  s.expect
                  s.flock
                  s.graphviz
                  s.pythonConfig
                ];
              }
            ))
            // {
              name = "gcc.restore-and-capture";
              run = ''
                ${s.python}/bin/python3 -B ${s.upstreamRestore} ${package.artifact}/nix-support/upstream-build-tree "$TVP_SOURCE_ROOT" ${s.checkpointScript}
                checkpoint="$(cat tree-path)"
                cd "$checkpoint/build"
                validation="$out"
                mkdir -p "$validation"
                cp -a ${package.artifact}/nix-support/production/. "$validation/"
                mapfile -t flags < "$validation/stage-flags.txt"
                ${import s.upstreamCapture {
                  inherit
                    lib
                    s
                    flags
                    includes
                    links
                    shell
                    libc
                    ;
                  sourceRoot = "$checkpoint";
                }}
              '';
            }
          )
        ];
      };
    args = { };
    dependencyNames = [ ];
    metadata.kind = "owned-validation";
    selection.kind = "owned-validation";
    mkTests = _: { };
  };
  acceptance = package.testContext.mkTest {
    package = execution;
    name = "upstream-audit";
    tools = [
      s.python
      s.grep
    ];
    script = ''
      test "$(cat ${execution}/make-check.exit)" = 0
      ${lib.optionalString s.bootstrap "grep -Fx 'Comparison successful.' ${execution}/bootstrap-compare.log >/dev/null"}
      ${s.python}/bin/python3 -B - ${execution}/upstream.json <<'PYTHON'
      import json, sys
      x = json.load(open(sys.argv[1]))
      suites = x['suites']
      assert suites and sum(s['counts'].get('PASS', 0) for s in suites.values()) > 0
      assert all(not s['unexpected'] for s in suites.values()), 'unclassified raw GCC 13 outcomes'
      PYTHON
      printf classified
    '';
    expected = "classified";
  };
in
{
  inherit execution acceptance;
}
