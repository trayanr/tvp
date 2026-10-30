{ tvp }:
tvp.bases.default.stdenv.mkDerivation {
  name = "tvp-audit-contracts";
  nativeBuildInputs = [ tvp.packages.python_3_12_16 ];
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    python3 ${./test_runtime.py} ${../runtime.py}
    python3 ${../../tools/graph/tests/test_graph.py} ${../../tools/graph/compare.py}
    printf audit-contracts-ok > "$out"
  '';
}
