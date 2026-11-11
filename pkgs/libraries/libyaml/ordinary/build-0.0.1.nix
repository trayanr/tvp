# 0.0.1: scalar/event API only; preserve archive-derived ABI filenames and static library.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  pkgConfig,
  gnumake,
  gnutar,
  gzip,
  python,
  binutils,
  patchelf,
  sed,
  grep,
  gawk,
  diffutils,
  findutils,
  file,
  doCheck ? true,
  cStandard ? null,
  commonSymbols ? false,
  touchTestsuite ? false,
  patches ? [ ],
  preparation,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "libyaml.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "libyaml";
  inherit
    base
    src
    version
    bash
    coreutils
    pkgConfig
    gnumake
    gnutar
    gzip
    python
    binutils
    patchelf
    sed
    grep
    gawk
    diffutils
    findutils
    file
    doCheck
    cStandard
    commonSymbols
    touchTestsuite
    patches
    preparation
    ;
  features = {
    shared = true;
    static = true;
    document = false;
    pkgConfig = false;
  };
  configureFlags = [
    (if final.features.shared then "--enable-shared" else "--disable-shared")
    (if final.features.static then "--enable-static" else "--disable-static")
  ];
  environment = {
    tools = [
      final.pkgConfig
      final.gnumake
      final.sed
      final.grep
      final.gawk
      final.diffutils
      final.findutils
      final.file
    ];
    libraries = [ ];
  };
  runtime.shell = final.bash;
  runtime.tools = [
    final.coreutils
    final.sed
    final.grep
    final.gawk
    final.diffutils
    final.findutils
  ];
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.gnutar;
      inherit (final) gzip findutils;
      compression = "gzip";
    })
    (command "prepare" ''
      ${final.python}/bin/python3 -B ${../../gdbm/ordinary/source.py} ${final.bash}/bin/bash ${
        lib.escapeShellArg (
          builtins.toJSON (
            final.preparation
            // {
              patches = map (p: "${p}") final.patches;
            }
          )
        )
      }
    '')
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      export CFLAGS="-O2${
        lib.optionalString (final.cStandard != null) " -std=${final.cStandard}"
      }${lib.optionalString final.commonSymbols " -fcommon"}"
      ./configure --prefix="$out" ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "build" make)
    (
      (command "check" ''
        ${lib.optionalString final.touchTestsuite "${make} -C tests package.m4\n${final.coreutils}/bin/touch tests/testsuite"}
              ${make} check'')
      // {
        enabled = final.doCheck;
      }
    )
    (command "install" ''
      ${make} install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "libyaml.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "libyaml.relocate";
      tools = [
        final.python
        final.binutils
        final.patchelf
      ];
      run = ''${final.python}/bin/python3 -B ${../../gdbm/ordinary/output.py} "$out" "$TVP_ARTIFACT_ROOT" ${final.patchelf}/bin/patchelf ${
        lib.escapeShellArg (
          builtins.toJSON {
            readelf = "${final.binutils}/bin/readelf";
            shell = "${final.runtime.shell}/bin/bash";
            buildShell = "${final.bash}/bin/bash";
            paths = map (p: "${p}/bin") final.runtime.tools;
            requiredDirectories = [
              "lib"
              "include"
              "nix-support"
            ];
            requiredFiles = [
              "lib/libyaml.a"
              "lib/libyaml.la"
              "include/yaml.h"
            ];
            libtoolData = [ "lib/libyaml.la" ];
            requiredRegular = [
              "lib/libyaml.a"
              "lib/libyaml.la"
              "include/yaml.h"
            ];
          }
        )
      }'';
    }

    (outputs.strip {
      inherit (final) python binutils;
      paths = [ "lib" ];
      elfKinds = [ "runtime" ];
    })
    (outputs.stripArchives {
      inherit (final) python binutils;
      paths = [ "lib/libyaml.a" ];
    })
    (outputs.libtool {
      inherit (final) python;
      paths = [ "lib/libyaml.la" ];
    })
    ((import ../../gdbm/ordinary/rpaths.nix { inherit lib; }) {
      inherit (final)
        python
        binutils
        patchelf
        base
        ;
      paths = [ "lib" ];
      elfKinds = [ "runtime" ];
      selfLibraryDirectory = true;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
    })
    (outputs.development {
      inherit (final) python;
      libraries = [ ];
    })
    ((import ../../gdbm/ordinary/check-paths.nix { inherit lib; }) {
      inherit (final) python binutils patchelf;
      paths = [ "lib" ];
      elfKinds = [ "runtime" ];
    })
  ];
  tvp.features = final.features;
  meta = {
    description = "C library for parsing and emitting YAML";
    homepage = "https://pyyaml.org/wiki/LibYAML";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
