# 3.0.9–3.0.13: libtool installs public headers beneath lib/libffi-VERSION/include.
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
  cStandard ? "gnu17",
  cFlags ? [ ],
  dejagnu,
  reportedVersion ? version,
  features,

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
      name = "libffi.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "libffi";
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
    cFlags
    dejagnu
    reportedVersion
    patches
    preparation
    ;
  inherit features;
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
      final.dejagnu
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
      export CFLAGS=${
        lib.escapeShellArg (
          lib.concatStringsSep " " (
            [ "-O2" ] ++ lib.optional (final.cStandard != null) "-std=${final.cStandard}" ++ final.cFlags
          )
        )
      }
      ./configure --prefix="$out" --libdir="$out/lib" ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "build" make)
    (
      (command "check" ''
        export TVP_TEST_C_STANDARD=${
          lib.escapeShellArg (if final.cStandard == null then "" else final.cStandard)
        }
        status=0
        ${final.coreutils}/bin/timeout --kill-after=10 1800 ${make} check RUNTEST=${final.dejagnu}/bin/runtest || status=$?
        ${final.findutils}/bin/find . -name libffi.log -type f -exec ${final.coreutils}/bin/cat {} \;
        exit "$status"
      '')
      // {
        enabled = final.doCheck;
      }
    )
    (command "install" ''
      ${make} install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "libffi.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "libffi.relocate";
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
              "lib/libffi-${final.version}/include"
              "nix-support"
            ];
            requiredFiles = [
              "lib/libffi.la"
              "lib/libffi-${final.version}/include/ffi.h"
              "lib/libffi-${final.version}/include/ffitarget.h"
              "lib/pkgconfig/libffi.pc"
            ] ++ lib.optional final.features.static "lib/libffi.a";
            libtoolData = [ "lib/libffi.la" ];
            requiredRegular = [
              "lib/libffi.la"
              "lib/libffi-${final.version}/include/ffi.h"
              "lib/libffi-${final.version}/include/ffitarget.h"
              "lib/pkgconfig/libffi.pc"
            ] ++ lib.optional final.features.static "lib/libffi.a";
          }
        )
      }'';
    }

    (outputs.strip {
      inherit (final) python binutils;
      paths = [ "lib" ];
      elfKinds = [ "runtime" ];
    })
    (
      (outputs.stripArchives {
        inherit (final) python binutils;
        paths = [ "lib/libffi.a" ];
      })
      // {
        enabled = final.features.static;
      }
    )
    (outputs.libtool {
      inherit (final) python;
      paths = [ "lib/libffi.la" ];
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
  development.includeDirectories = [ "lib/libffi-${final.version}/include" ];
  tvp.cc = final.base.compiler;
  tvp.features = final.features;
  tvp.reportedVersion = final.reportedVersion;
  meta = {
    description = "Foreign function interface library";
    homepage = "https://sourceware.org/libffi/";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
