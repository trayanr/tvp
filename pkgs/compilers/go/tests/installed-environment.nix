# Immutable raw observation belongs to the final installed control, never A/F.
{ package }:
let s = package.specification;
in (package.testContext.mkTest {
  inherit package;
  name = "installed-environment";
  script = ":";
  expected = "";
}).edit (spec: spec // {
  plan = [ ((s.base.environment { tools = [ s.coreutils s.helperPython ]; }) // {
    name = "go.observe-installed-environment";
    run = ''
      unset GOROOT CC CXX
      export GOENV=off GOTOOLCHAIN=local GOPROXY=off GOSUMDB=off
      export GOCACHE="$TMPDIR/go-cache" GOPATH="$TMPDIR/go-work"
      mkdir -p "$out"
      ${package}/bin/go env -json > "$out/installed-environment.json"
      ${package}/share/go/bin/go env -json > "$out/nested-environment.json"
      ln -s ${package}/bin/go public-go
      ./public-go env -json > "$out/symlink-environment.json"
      ln -s ${package}/share/go explicit-root
      GOROOT="$PWD/explicit-root" ${package}/bin/go env GOROOT > "$out/explicit-goroot"
      test "$(cat "$out/explicit-goroot")" = "$PWD/explicit-root"
      ${s.helperPython}/bin/python3 -B - "$out" <<'PY'
      import json
      from pathlib import Path
      import sys
      root = Path(sys.argv[1])
      for name in ['installed-environment.json', 'nested-environment.json', 'symlink-environment.json']:
          x = json.loads((root / name).read_bytes())
          assert x['GOROOT'] == '${package}/share/go'
          assert x['GOTOOLDIR'] == '${package}/share/go/pkg/tool/${s.goOS}_${s.goArch}'
      (root / 'result').write_text('observed\n')
      PY
    '';
  }) ];
})
