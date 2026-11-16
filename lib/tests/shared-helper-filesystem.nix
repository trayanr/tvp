# Isolated helper filesystem controls; source selection contains no packages.
{
  lib,
  builder,
  base,
}:
let
  python = (import ../../bootstrap { }).build-python;
  context = (import ../tests.nix { inherit lib; }).forBase {
    inherit builder base;
    coreutils = base.coreutils;
  };
  source = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ./shared-checkpoint-output.py
      ../build-checkpoint.py
      ../restore-checkpoint.py
      ../relocate.py
      ../check-loader-paths.py
      ../native-output/check-paths.py
      ../native-output/common.py
    ];
  };
in
context.mkTest {
  package = python // {
    pname = "shared-helper-tools";
    version = "1";
  };
  name = "shared-helper-filesystem";
  script = ''
    ${python}/bin/python3 -B ${source}/tests/shared-checkpoint-output.py >&2
    printf shared-helpers-ok
  '';
  expected = "shared-helpers-ok";
}
