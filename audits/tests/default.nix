{ tvp }:
let
  registration = import ./provenance.nix { inherit tvp; };
in
assert builtins.all (passed: passed) (builtins.attrValues registration);
tvp.bases.default.stdenv.mkDerivation {
  name = "tvp-audit-contracts";
  nativeBuildInputs = [ tvp.packages.python_3 ];
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    python3 ${./test_runtime.py} ${../runtime.py}
    python3 ${../../tools/graph/tests/test_graph.py} ${../../tools/graph/compare.py}
    printf audit-contracts-ok > "$out"
  '';
}
