{ lib }:

{
  python,
  binutils,
  patchelf,
  base,
  paths,
  libraries,
  dlopenDirectories ? [ ],
  elfKinds ? null,
}:
{
  name = "output.rpaths";
  tools = [
    python
    binutils
    patchelf
  ];
  run = ''${python}/bin/python3 -B ${./ordinary-compression-rpaths.py} "$out" ${
    lib.escapeShellArg (
      builtins.toJSON {
        inherit paths dlopenDirectories elfKinds;
        libraries = lib.concatMap (
          p: (p.development or { }).libraryDirectories or [ "${lib.getLib p}/lib" ]
        ) libraries;
        baseDirectories = base.runtimeDirectories;
        readelf = "${binutils}/bin/readelf";
        patchelf = "${patchelf}/bin/patchelf";
      }
    )
  } ${../../lib/native-output}'';
}
