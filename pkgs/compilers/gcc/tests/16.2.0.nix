{
  pkgs,
  tvpLib,
  gcc,
}:
{
  upstream =
    pkgs.runCommand "gcc-${gcc.version}-upstream-results" { nativeBuildInputs = [ pkgs.python3 ]; }
      ''
        python3 - ${gcc.validation}/upstream.json <<'PY'
        import json, sys
        data = json.load(open(sys.argv[1]))
        suites = data["suites"]
        assert suites, "No actual upstream results"
        for tool in ["gcc", "g++", "libstdc++", "libgomp", "libatomic", "libitm", "libquadmath", "asan", "ubsan"]:
            found = [s for name, s in suites.items() if name.endswith("/" + tool + ".sum")]
            assert found and sum(s["counts"].get("PASS", 0) for s in found) > 0, tool
        unexpected = {name: s["unexpected"] for name, s in suites.items() if s["unexpected"]}
        assert not unexpected, json.dumps(unexpected, indent=2)
        PY
        mkdir -p "$out"
        cp ${gcc.validation}/upstream.json "$out/results.json"
        ln -s ${gcc.validation} "$out/raw"
      '';
}
