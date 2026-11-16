# Inspect only references reachable from the actual installed output. Expected
# libraries are context-free strings, never graph roots or injected references.
{ lib }:
{
  package,
  context,
  python,
}:
let
  expectedLibraries = map (p: builtins.unsafeDiscardStringContext (toString p)) (
    package.runtime.libraries or [ ]
  );
in
(context.mkTest {
  inherit package;
  name = "runtime-expectation";
  tools = [ python ];
  script = ''
    ${python}/bin/python3 - "$TVP_SOURCE_ROOT/.tvp-reference-graph.json" <<'PYCODE'
    import json, sys
    from pathlib import Path
    attrs = json.loads(Path(sys.argv[1]).read_text())
    reachable = {row['path'] for row in attrs['package']}
    expected = json.loads(${builtins.toJSON (builtins.toJSON expectedLibraries)})
    absent = set(expected) - reachable
    assert not absent, 'Runtime libraries absent from package closure: ' + repr(sorted(absent))
    print('runtime-ok')
    PYCODE
  '';
  expected = "runtime-ok";
}).edit
  (
    s:
    s
    // {
      exportReferencesGraph.package = [ package.out ];
      passthru = s.passthru // {
        inherit expectedLibraries;
      };
    }
  )
