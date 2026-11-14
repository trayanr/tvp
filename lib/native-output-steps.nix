# Internal native x86_64 Linux output helpers. Each returns one ordinary record;
# the recipe selects and orders them. No inherited finalization dispatch.
{ lib }:
let
  script = name: "${./native-output}/${name}.py";
  checkedOutput =
    output:
    if !builtins.isString output || builtins.hasContext output then
      throw "TVP output helper: expected a context-free output name"
    else if output == "out" then
      output
    else
      builtins.elemAt (import ./named-outputs.nix { inherit lib; } [
        "out"
        output
      ]) 1;
  root = output: ''"${"$" + checkedOutput output}"'';
  forOutput =
    output: step:
    step // lib.optionalAttrs (output != "out") { outputSelection = checkedOutput output; };
  # The runner's artifact binding is readonly. Select the matching prefix only
  # for this Python invocation; default commands retain their existing inputs.
  invoke =
    output: python: program: arguments:
    if output == "out" then
      ''${python}/bin/python3 -B ${program} ${arguments}''
    else
      ''
        if declare -p TVP_ARTIFACT_OUTPUTS > /dev/null 2>&1; then
          TVP_HELPER_ARTIFACT_ROOT="''${TVP_ARTIFACT_OUTPUTS[${checkedOutput output}]:?missing selected artifact output}"
        else
          TVP_HELPER_ARTIFACT_ROOT=""
        fi
        ${python}/bin/python3 -B ${./output-root.py} "$TVP_HELPER_ARTIFACT_ROOT" ${program} ${arguments}
      '';
  run =
    output: python: name: config:
    invoke output python (script name)
      ''${root output} ${lib.escapeShellArg (builtins.toJSON config)}'';
  sdkOutputRun =
    output: python: name: config:
    invoke output python "${./sdk-output}/${name}.py"
      ''${root output} ${lib.escapeShellArg (builtins.toJSON config)} ${./native-output} ${./output-tools}'';
  outputRun =
    output: python: name: config:
    invoke output python "${./output-tools}/${name}.py"
      ''${root output} ${lib.escapeShellArg (builtins.toJSON config)} ${./native-output}'';
  selectedRun =
    output: python: name: config: kinds:
    if kinds == null then
      run output python name config
    else
      invoke output python ./elf-output.py
        ''${root output} ${
          lib.escapeShellArg (builtins.toJSON (config // { inherit kinds; }))
        } ${./native-output} ${name}'';

in
{
  interpreters =
    {
      output ? "out",
      python,
      binutils,
      patchelf,
      paths,
      loader,
    }:
    forOutput output {
      name = "output.interpreters";
      tools = [
        python
        binutils
        patchelf
      ];
      run = sdkOutputRun output python "interpreters" {
        inherit paths loader;
        readelf = "${binutils}/bin/readelf";
        patchelf = "${patchelf}/bin/patchelf";
      };
    };
  template =
    {
      output ? "out",
      python,
      path,
      template,
      values,
    }:
    forOutput output {
      name = "output.template";
      tools = [ python ];
      run = sdkOutputRun output python "template" { inherit path template values; };
    };
  # Shallow host ELF selection; target payloads never enter this operation.
  hostELF =
    {
      output ? "out",
      python,
      binutils,
      patchelf,
      paths,
      patterns ? [ ],
      loader,
      libraries,
      executablesOnly ? false,
    }:
    forOutput output {
      name = "output.host-elf";
      tools = [
        python
        binutils
        patchelf
      ];
      run =
        invoke output python (if executablesOnly then ./sdk-output/host-executables.py else ./host-elf.py)
          ''${root output} ${
            lib.escapeShellArg (
              builtins.toJSON {
                inherit paths patterns loader;
                libraries = map (p: "${lib.getLib p}/lib") libraries;
                readelf = "${binutils}/bin/readelf";
                patchelf = "${patchelf}/bin/patchelf";
              }
            )
          } ${./native-output}'';
    };
  copyArtifacts =
    {
      coreutils,
      outputs ? null,
      preserveHardlinks ? true,
    }:
    let
      names = if outputs == null then null else import ./named-outputs.nix { inherit lib; } outputs;
      noPreserve = if preserveHardlinks then "ownership" else "ownership,links";
    in
    {
      name = "output.copy-artifacts";
      tools = [ coreutils ];
      run =
        if names != null && names != [ "out" ] then
          # An explicit complete set; the constructor supplies a readonly map.
          ''
            test "''${#TVP_ARTIFACT_OUTPUTS[@]}" -eq ${toString (builtins.length names)}
          ''
          + lib.concatMapStringsSep "\n" (name: ''
            test -n "''${TVP_ARTIFACT_OUTPUTS[${name}]:?missing artifact output ${name}}"
            test -d "''${TVP_ARTIFACT_OUTPUTS[${name}]}"
            test -n "''${${name}:?missing final output ${name}}"
            test ! -e "${"$" + name}"
            ${coreutils}/bin/cp -a --no-preserve=${noPreserve} "''${TVP_ARTIFACT_OUTPUTS[${name}]}" "${"$" + name}"
            ${coreutils}/bin/chmod -R u+w "${"$" + name}"
          '') names
          + ''
            if [[ -f "$out/nix-support/source-date-epoch" ]]; then
              ${coreutils}/bin/cp "$out/nix-support/source-date-epoch" source-date-epoch
            fi
          ''
        else
          ''
            test -n "$TVP_ARTIFACT_ROOT"
            ${coreutils}/bin/cp -a --no-preserve=${noPreserve} "$TVP_ARTIFACT_ROOT" "$out"
            ${coreutils}/bin/chmod -R u+w "$out"
            if [[ -f "$out/nix-support/source-date-epoch" ]]; then
              ${coreutils}/bin/cp "$out/nix-support/source-date-epoch" source-date-epoch
            fi
          '';
    }
    // lib.optionalAttrs (names != null) { artifactOutputSelection = names; };
  relocateText =
    {
      output ? "out",
      python,
      paths,
    }:
    forOutput output {
      name = "output.relocate-text";
      tools = [ python ];
      run =
        invoke output python ./owned-output/relocate.py
          ''${root output} ${lib.escapeShellArg (builtins.toJSON { inherit paths; })} ${./native-output}'';
    };
  # Select normal GNU native non-LTO .a archives, strip debug data, then restore
  # their index. Fixed -S -p / -D operation; all selected tool failures fail.
  # Example: output.stripArchives { inherit python binutils; paths = [ "lib" ]; }
  stripArchives =
    {
      output ? "out",
      python,
      binutils,
      paths,
    }:
    forOutput output {
      name = "output.strip-archives";
      tools = [
        python
        binutils
      ];
      run = outputRun output python "strip-archives" {
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
      output ? "out",
      python,
      paths,
      names,
      interpreter ? null,
      selfInterpreter ? null,
    }:
    forOutput output {
      name = "output.shebangs";
      tools = [ python ];
      run = outputRun output python "shebangs" {
        inherit paths names selfInterpreter;
        interpreter = if interpreter == null then null else toString interpreter;
      };
    };
  strip =
    {
      output ? "out",
      python,
      binutils,
      paths,
      elfKinds ? null,
      flags ? [
        "-S"
        "-p"
      ],
    }:
    forOutput output {
      name = "output.strip";
      tools = [
        python
        binutils
      ];
      run = selectedRun output python "strip" {
        inherit paths flags;
        readelf = "${binutils}/bin/readelf";
        strip = "${binutils}/bin/strip";
      } elfKinds;
    };
  libtool =
    {
      output ? "out",
      python,
      paths,
    }:
    forOutput output {
      name = "output.libtool";
      tools = [ python ];
      run = run output python "libtool" { inherit paths; };
    };
  rpaths =
    {
      output ? "out",
      python,
      binutils,
      patchelf,
      paths,
      elfKinds ? null,
      dlopenDirectories ? [ ],
      forceRpath ? false,
      workspaceRoot ? null,
      base ? null,
      libraries ? null,
    }:
    assert
      workspaceRoot == null
      || output == "out"
      || throw "TVP output.rpaths: workspaceRoot cannot select an installed output";
    assert workspaceRoot == null || (base == null && libraries == null && !forceRpath);
    assert !forceRpath || (base != null && libraries != null && dlopenDirectories != [ ]);
    forOutput output {
      name = "output.rpaths";
      tools = [
        python
        binutils
        patchelf
      ];
      run =
        if workspaceRoot != null then
          builtins.seq (checkedOutput output) ''${python}/bin/python3 -B ${./staged-output/rpaths.py} "$TVP_SOURCE_ROOT" ${
            lib.escapeShellArg (
              builtins.toJSON {
                inherit
                  workspaceRoot
                  paths
                  dlopenDirectories
                  elfKinds
                  ;
                readelf = "${binutils}/bin/readelf";
                patchelf = "${patchelf}/bin/patchelf";
              }
            )
          } ${./native-output} ${./elf-output.py}''
        else if libraries != null then
          invoke output python
            (if forceRpath then ./owned-output/dlopen-rpaths.py else ./owned-output/rpaths.py)
            ''${root output} ${
              lib.escapeShellArg (
                builtins.toJSON {
                  inherit paths dlopenDirectories elfKinds;
                  libraries = lib.concatMap (
                    p: (p.development or { }).libraryDirectories or [ "${lib.getLib p}/lib" ]
                  ) libraries;
                  baseDirectories =
                    if base == null then
                      [ ]
                    else if base ? runtimeDirectories then
                      assert builtins.isList base.runtimeDirectories;
                      assert builtins.all (
                        p: builtins.isString p && builtins.hasContext p && lib.hasPrefix "/nix/store/" p
                      ) base.runtimeDirectories;
                      base.runtimeDirectories
                    else
                      [
                        "${base.stdenv.cc.libc}/lib"
                        "${base.stdenv.cc.cc}/lib"
                      ];
                  readelf = "${binutils}/bin/readelf";
                  patchelf = "${patchelf}/bin/patchelf";
                }
              )
            } ${./native-output}${lib.optionalString forceRpath " ${./owned-output/rpaths.py}"}''
        else
          selectedRun output python "rpaths" {
            inherit paths dlopenDirectories;
            readelf = "${binutils}/bin/readelf";
            patchelf = "${patchelf}/bin/patchelf";
          } elfKinds;
    };
  development =
    {
      output ? "out",
      python,
      libraries,
    }:
    forOutput output {
      name = "output.development";
      tools = [ python ];
      inherit libraries;
      developmentLibraries = libraries;
      run = run output python "development" { libraries = map toString libraries; };
    };
  checkSymlinks =
    {
      output ? "out",
      python,
      paths,
    }:
    forOutput output {
      name = "output.check-symlinks";
      tools = [ python ];
      run = run output python "check-symlinks" { inherit paths; };
    };
  # Audit a directory tree; unlike checkSymlinks, selectors are directories.
  checkSymlinkTree =
    {
      output ? "out",
      python,
      paths,
    }:
    forOutput output {
      name = "output.check-symlink-tree";
      tools = [ python ];
      run =
        invoke output python ./symlink-tree.py
          ''${root output} ${lib.escapeShellArg (builtins.toJSON { inherit paths; })} ${./native-output}'';
    };
  checkPaths =
    {
      output ? "out",
      python,
      binutils,
      patchelf,
      paths,
      elfKinds ? null,
    }:
    forOutput output {
      name = "output.check-paths";
      tools = [
        python
        binutils
        patchelf
      ];
      run = selectedRun output python "check-paths" {
        inherit paths;
        readelf = "${binutils}/bin/readelf";
        patchelf = "${patchelf}/bin/patchelf";
      } elfKinds;
    };
}
