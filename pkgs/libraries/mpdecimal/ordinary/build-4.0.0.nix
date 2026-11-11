# 4.0.0 only: compiler-driver shared links (LD=CC), C/C++ and offline check_local.
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
  linkWithCC ? true,
  features ? {
    shared = true;
    static = true;
    cxx = true;
  },

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
      name = "mpdecimal.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "mpdecimal";
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
    linkWithCC
    patches
    preparation
    ;
  inherit features;
  configureFlags = [
    (if final.features.cxx then "--enable-cxx" else "--disable-cxx")

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
      ${final.python}/bin/python3 -B ${../../libffi/ordinary/source.py} ${final.bash}/bin/bash ${
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
      ./configure --prefix="$out" --libdir="$out/lib" ${lib.escapeShellArgs final.configureFlags} ${lib.optionalString final.linkWithCC "LD=$CC"}
    '')
    (command "build" make)
    (
      (command "check" ''
        ${make} check_local
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
    (steps.split "mpdecimal.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "mpdecimal.relocate";
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
            requiredFiles =
              [
                "include/mpdecimal.h"
                "lib/pkgconfig/libmpdec.pc"
              ]
              ++ lib.optional final.features.static "lib/libmpdec.a"
              ++ lib.optionals final.features.cxx (
                [
                  "include/decimal.hh"
                  "lib/pkgconfig/libmpdec++.pc"
                ]
                ++ lib.optional final.features.static "lib/libmpdec++.a"
              );
            libtoolData = [ ];
            requiredRegular =
              [
                "include/mpdecimal.h"
                "lib/pkgconfig/libmpdec.pc"
              ]
              ++ lib.optional final.features.static "lib/libmpdec.a"
              ++ lib.optionals final.features.cxx (
                [
                  "include/decimal.hh"
                  "lib/pkgconfig/libmpdec++.pc"
                ]
                ++ lib.optional final.features.static "lib/libmpdec++.a"
              );
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
        paths = [ "lib/libmpdec.a" ] ++ lib.optional final.features.cxx "lib/libmpdec++.a";
      })
      // {
        enabled = final.features.static;
      }
    )
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
  tvp.cc = final.base.compiler;
  tvp.features = final.features;
  meta = {
    description = "Correctly rounded arbitrary-precision decimal arithmetic libraries";
    homepage = "https://www.bytereef.org/mpdecimal/";
    license = lib.licenses.bsd2;
    platforms = [ "x86_64-linux" ];
  };
}
