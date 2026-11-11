# Explicit final audit for the loader spelling supported by these recipes.
{ lib }:
{
  python,
  binutils,
  patchelf,
  paths,
  elfKinds ? null,
}:
{
  name = "output.check-paths";
  tools = [
    python
    binutils
    patchelf
  ];
  run = ''${python}/bin/python3 -B ${./ordinary-text-check-paths.py} "$out" ${
    lib.escapeShellArg (
      builtins.toJSON {
        inherit paths elfKinds;
        readelf = "${binutils}/bin/readelf";
        patchelf = "${patchelf}/bin/patchelf";
      }
    )
  } ${../../lib/native-output}'';
}
