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
// tvpLib.tests.mkSuite {
  inherit pkgs;
  package = gcc;
  tests = {
    runtime = {
      script = ''
        ${gcc}/bin/g++ ${flags} -std=c++20 -flto ${./fixtures/runtime-16.cc} -o runtime
        ${pkgs.binutils}/bin/readelf -l runtime | grep -F '${libc}/${gcc.platform.dynamicLinker}' >/dev/null
        ./runtime
      '';
      expected = "42\n${gcc}/lib/libstdc++.so.6";
    };
    graphite = {
      script = ''
        ${gcc}/bin/gcc ${flags} -O2 -fgraphite-identity -floop-nest-optimize -fdump-tree-graphite-details ${./fixtures/graphite.c} -o graphite
        grep -E 'number of SCoPs: [1-9]' *.graphite >/dev/null
        ./graphite
      '';
      expected = "3840";
    };
    actual-binutils = {
      extraInputs = [ pkgs.strace ];
      script = ''
        strace -f -e trace=execve -o selected ${gcc}/bin/gcc ${flags} ${./fixtures/hello.c} -o hello
        grep -F 'execve("${gcc.tvp.deps.binutils}/bin/as"' selected >/dev/null
        grep -F 'execve("${gcc.tvp.deps.binutils}/bin/ld"' selected >/dev/null
        ./hello
      '';
      expected = "42";
    };
  };
}
