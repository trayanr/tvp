{ scope }:
let
  inherit (scope) kaem tinycc-mes;
in
{
  consumer = kaem.runCommand "tvp-bootstrap-c-consumer" { } ''
    mkdir -p ''${out}/bin
    ${tinycc-mes.compiler}/bin/tcc -B ${tinycc-mes.libs}/lib -static \
      -o ''${out}/bin/consumer ${./consumer.c}
    ''${out}/bin/consumer
  '';
  versions = tinycc-mes.compiler.tests.chain;
}
// import ./ladder-tests.nix { inherit scope; }
