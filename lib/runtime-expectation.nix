# Inspect only references reachable from the actual installed output. Expected
# libraries are context-free strings, never graph roots or injected references.
{ lib }:
{
  package,
  stdenv,
  python,
}:
stdenv.mkDerivation {
  name = "${package.name}-runtime-expectation";
  __structuredAttrs = true;
  exportReferencesGraph.package = [ package.out ];
  expectedLibraries = map (p: builtins.unsafeDiscardStringContext (toString p)) (
    package.runtime.libraries or [ ]
  );
  nativeBuildInputs = [ python ];
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  dontFixup = true;
  installPhase = ''
    python3 - <<'PY'
    import json, os
    from pathlib import Path
    attrs = json.loads(Path(os.environ['NIX_ATTRS_JSON_FILE']).read_text())
    reachable = {row['path'] for row in attrs['package']}
    absent = set(attrs['expectedLibraries']) - reachable
    assert not absent, 'Runtime libraries absent from package closure: ' + repr(sorted(absent))
    Path(attrs['outputs']['out']).write_text(json.dumps(dict(reachable=sorted(reachable), expected=attrs['expectedLibraries'])))
    PY
  '';
}
