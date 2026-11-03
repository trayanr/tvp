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
  selectedRun =
    python: name: config: kinds:
    if kinds == null then
      run python name config
    else
      ''${python}/bin/python3 -B ${./elf-output.py} "$out" ${
        lib.escapeShellArg (builtins.toJSON (config // { inherit kinds; }))
      } ${./native-output} ${name}'';
in
{
  copyArtifacts =
    { coreutils }:
    {
      name = "output.copy-artifacts";
      tools = [ coreutils ];
      run = ''
        test -n "$TVP_ARTIFACT_ROOT"
        ${coreutils}/bin/cp -a --no-preserve=ownership "$TVP_ARTIFACT_ROOT" "$out"
        ${coreutils}/bin/chmod -R u+w "$out"
        if [[ -f "$out/nix-support/source-date-epoch" ]]; then
          ${coreutils}/bin/cp "$out/nix-support/source-date-epoch" source-date-epoch
        fi
      '';
    };
  relocateText =
    { python, paths }:
    {
      name = "output.relocate-text";
      tools = [ python ];
      run = ''${python}/bin/python3 -B ${./owned-output/relocate.py} "$out" ${
        lib.escapeShellArg (builtins.toJSON { inherit paths; })
      } ${./native-output}'';
    };
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
      elfKinds ? null,
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
      run = selectedRun python "strip" {
        inherit paths flags;
        readelf = "${binutils}/bin/readelf";
        strip = "${binutils}/bin/strip";
      } elfKinds;
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
      elfKinds ? null,
      dlopenDirectories ? [ ],
      base ? null,
      libraries ? null,
    }:
    {
      name = "output.rpaths";
      tools = [
        python
        binutils
        patchelf
      ];
      run =
        if libraries != null then
          assert base != null;
          ''${python}/bin/python3 -B ${./owned-output/rpaths.py} "$out" ${
            lib.escapeShellArg (
              builtins.toJSON {
                inherit paths dlopenDirectories;
                libraries = map (p: "${lib.getLib p}/lib") libraries;
                baseDirectories = [
                  "${base.stdenv.cc.libc}/lib"
                  "${base.stdenv.cc.cc}/lib"
                ];
                readelf = "${binutils}/bin/readelf";
                patchelf = "${patchelf}/bin/patchelf";
              }
            )
          } ${./native-output}''
        else
          selectedRun python "rpaths" {
            inherit paths dlopenDirectories;
            readelf = "${binutils}/bin/readelf";
            patchelf = "${patchelf}/bin/patchelf";
          } elfKinds;
    };
  development =
    { python, libraries }:
    {
      name = "output.development";
      tools = [ python ];
      inherit libraries;
      developmentLibraries = libraries;
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
      elfKinds ? null,
    }:
    {
      name = "output.check-paths";
      tools = [
        python
        binutils
        patchelf
      ];
      run = selectedRun python "check-paths" {
        inherit paths;
        readelf = "${binutils}/bin/readelf";
        patchelf = "${patchelf}/bin/patchelf";
      } elfKinds;
    };
}
