# Internal native x86_64 Linux output helpers. Each returns one ordinary record;
# the recipe selects and orders them. No inherited finalization dispatch.
{ lib }:
let
  script = name: "${./native-output}/${name}.py";
  run =
    python: name: config:
    ''${python}/bin/python3 -B ${script name} "$out" ${lib.escapeShellArg (builtins.toJSON config)}'';
in
{
  strip =
    {
      python,
      binutils,
      paths,
      flags ? [
        "-S"
        "-p"
      ],
    }:
    {
      name = "output.strip";
      tools = [
        python
        binutils
      ];
      run = run python "strip" {
        inherit paths flags;
        readelf = "${binutils}/bin/readelf";
        strip = "${binutils}/bin/strip";
      };
    };
  libtool =
    { python, paths }:
    {
      name = "output.libtool";
      tools = [ python ];
      run = run python "libtool" { inherit paths; };
    };
  rpaths =
    {
      python,
      binutils,
      patchelf,
      paths,
      dlopenDirectories ? [ ],
    }:
    {
      name = "output.rpaths";
      tools = [
        python
        binutils
        patchelf
      ];
      run = run python "rpaths" {
        inherit paths dlopenDirectories;
        readelf = "${binutils}/bin/readelf";
        patchelf = "${patchelf}/bin/patchelf";
      };
    };
  development =
    { python, libraries }:
    {
      name = "output.development";
      tools = [ python ];
      inherit libraries;
      run = run python "development" { libraries = map toString libraries; };
    };
  checkSymlinks =
    { python, paths }:
    {
      name = "output.check-symlinks";
      tools = [ python ];
      run = run python "check-symlinks" { inherit paths; };
    };
  checkPaths =
    {
      python,
      binutils,
      patchelf,
      paths,
    }:
    {
      name = "output.check-paths";
      tools = [
        python
        binutils
        patchelf
      ];
      run = run python "check-paths" {
        inherit paths;
        readelf = "${binutils}/bin/readelf";
        patchelf = "${patchelf}/bin/patchelf";
      };
    };
}
