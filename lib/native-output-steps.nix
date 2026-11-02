# Internal native x86_64 Linux output helpers. Each returns one ordinary record;
# the recipe selects and orders them. No inherited finalization dispatch.
{ lib }:
let
  script = name: "${./native-output}/${name}.py";
  run =
    python: name: config:
    ''${python}/bin/python3 -B ${script name} "$out" ${lib.escapeShellArg (builtins.toJSON config)}'';
  outputRun =
    python: name: config:
    ''${python}/bin/python3 -B ${./output-tools}/${name}.py "$out" ${lib.escapeShellArg (builtins.toJSON config)} ${./native-output}'';
in
{
  # Select normal GNU native non-LTO .a archives, strip debug data, then restore
  # their index. Fixed -S -p / -D operation; all selected tool failures fail.
  # Example: output.stripArchives { inherit python binutils; paths = [ "lib" ]; }
  stripArchives =
    {
      python,
      binutils,
      paths,
    }:
    {
      name = "output.strip-archives";
      tools = [
        python
        binutils
      ];
      run = outputRun python "strip-archives" {
        inherit paths;
        readelf = "${binutils}/bin/readelf";
        strip = "${binutils}/bin/strip";
        ranlib = "${binutils}/bin/ranlib";
      };
    };
  # Select executable scripts by interpreter basename. Exactly one target:
  # interpreter = "${bash}/bin/bash" (a contextual, declared runtime path), OR
  # selfInterpreter = "bin/interpreter" (validated under this output at runtime).
  # Example names = [ "bash" "sh" ]; paths = [ "bin" ]. No PATH discovery.
  # Direct argument tails survive. env NAME / env -S NAME without arguments
  # convert to direct form; matching options/assignments/argument forms fail.
  shebangs =
    {
      python,
      paths,
      names,
      interpreter ? null,
      selfInterpreter ? null,
    }:
    {
      name = "output.shebangs";
      tools = [ python ];
      run = outputRun python "shebangs" {
        inherit paths names selfInterpreter;
        interpreter = if interpreter == null then null else toString interpreter;
      };
    };
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
