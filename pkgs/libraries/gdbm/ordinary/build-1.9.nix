# Automake 1.9–1.9.1: generate package.m4 and touch the shipped testsuite immediately before checks.
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
      name = "gdbm.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "gdbm";
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
    compatLib = true;
  };
  configureFlags = [
    (if final.features.shared then "--enable-shared" else "--disable-shared")
    (if final.features.static then "--enable-static" else "--disable-static")
  ] ++ lib.optional final.features.compatLib "--enable-libgdbm-compat";
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
      ${final.python}/bin/python3 -B ${./source.py} ${final.bash}/bin/bash ${
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
      mkdir -p "$out/include/gdbm"
      ln -s ../dbm.h ../gdbm.h ../ndbm.h "$out/include/gdbm/"
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "gdbm.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "gdbm.relocate";
      tools = [
        final.python
        final.binutils
        final.patchelf
      ];
      run = ''${final.python}/bin/python3 -B ${./output.py} "$out" "$TVP_ARTIFACT_ROOT" ${final.patchelf}/bin/patchelf ${
        lib.escapeShellArg (
          builtins.toJSON {
            readelf = "${final.binutils}/bin/readelf";
            shell = "${final.runtime.shell}/bin/bash";
            buildShell = "${final.bash}/bin/bash";
            paths = map (p: "${p}/bin") final.runtime.tools;
            requiredDirectories = [
              "lib"
              "include"
              "share/man"
              "nix-support"
            ];
            requiredFiles = [
              "lib/libgdbm.a"
              "lib/libgdbm.la"
              "lib/libgdbm_compat.a"
              "lib/libgdbm_compat.la"
              "include/gdbm.h"
              "include/dbm.h"
              "include/ndbm.h"
            ];
            libtoolData = [
              "lib/libgdbm.la"
              "lib/libgdbm_compat.la"
            ];
            requiredRegular = [
              "lib/libgdbm.a"
              "lib/libgdbm.la"
              "lib/libgdbm_compat.a"
              "lib/libgdbm_compat.la"
              "include/gdbm.h"
              "include/dbm.h"
              "include/ndbm.h"
            ];
          }
        )
      }'';
    }
    {
      name = "gdbm.manuals";
      tools = [
        final.gzip
        final.findutils
        final.file
      ];
      run = ''
        while IFS= read -r -d "" p; do
          ${final.gzip}/bin/gzip -n -9 "$p"
        done < <(${final.findutils}/bin/find "$out/share/man" -type f ! -name '*.gz' -print0)
        while IFS= read -r -d "" p; do
          target=$(readlink "$p"); rm "$p"; ln -s "$target.gz" "$p.gz"
        done < <(${final.findutils}/bin/find "$out/share/man" -type l ! -name '*.gz' -print0)
      '';
    }
    (outputs.strip {
      inherit (final) python binutils;
      paths = [
        "lib"
        "bin"
      ];
      elfKinds = [ "runtime" ];
    })
    (outputs.stripArchives {
      inherit (final) python binutils;
      paths = [
        "lib/libgdbm.a"
        "lib/libgdbm_compat.a"
      ];
    })
    (outputs.libtool {
      inherit (final) python;
      paths = [
        "lib/libgdbm.la"
        "lib/libgdbm_compat.la"
      ];
    })
    ((import ./rpaths.nix { inherit lib; }) {
      inherit (final)
        python
        binutils
        patchelf
        base
        ;
      paths = [
        "lib"
        "bin"
      ];
      elfKinds = [ "runtime" ];
      selfLibraryDirectory = true;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
    })
    (outputs.development {
      inherit (final) python;
      libraries = [ ];
    })
    ((import ./check-paths.nix { inherit lib; }) {
      inherit (final) python binutils patchelf;
      paths = [
        "lib"
        "bin"
      ];
      elfKinds = [ "runtime" ];
    })
  ];
  tvp.features = final.features;
  meta = {
    description = "GNU dbm key/value database library";
    homepage = "https://www.gnu.org/software/gdbm/";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
    mainProgram = "gdbmtool";
  };
}
