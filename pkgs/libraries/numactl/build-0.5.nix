# Upstream Unix Makefile releases. Build the public tools and libraries directly
# to keep benchmark-only and kernel-dependent test targets out of production.
{
  tvp,
  lib,
  base,
  src,
  version,
  extraPrograms ? [ ],
  compression ? "gzip",
  compiledNumastat ? false,
  staticLibrary ? false,
  compatibilityHeader ? false,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = steps.command { environment = final.environment; };
  programs = [
    "numactl"
    "numademo"
  ]
  ++ final.extraPrograms;
  make = ''
    ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash \
      CC="$CC" AR="$AR" prefix="$out" libdir="$out/lib"'';
in
{
  pname = "numactl";
  inherit
    base
    src
    version
    extraPrograms
    compression
    compiledNumastat
    staticLibrary
    compatibilityHeader
    ;
  inherit (tools) bash coreutils;
  installedInterface = {
    static = final.staticLibrary;
    pkgconfig = false;
    cliVersion = false;
  };
  environment = {
    tools = [
      tools.gnumake
      tools.grep
      tools.sed
    ];
    overrides.flags.NIX_CFLAGS_COMPILE = [
      "-std=gnu17"
      "-fcommon"
      "-D_FILE_OFFSET_BITS=64"
    ];
  };
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      inherit (final) compression;
    })
    (lib.optional (lib.versionAtLeast final.version "0.6") (
      command "numactl.large-file-api" ''
        # Keep 64-bit offsets using the standard stat interface.
        test "$(grep -Fc 'struct stat64 st;' shm.c)" = 1
        test "$(grep -Fc 'fstat64(shmfd, &st)' shm.c)" = 1
        sed -i -e 's/struct stat64 st;/struct stat st;/' -e 's/fstat64(/fstat(/' shm.c
      ''
    ))
    (lib.optional (lib.versionAtLeast final.version "2.0.8") (
      command "numactl.device-number-headers" ''
        test "$(grep -Fxc '#include <sys/stat.h>' affinity.c)" = 1
        sed -i '/^#include <sys\/stat.h>$/a #include <sys/sysmacros.h>' affinity.c
      ''
    ))
    (command "numactl.build" ''
      # 0.8 ships a precompiled distance.o. 2.0.8 ships an old numastat
      # alongside its C source. All installed native code must be built here.
      rm -f distance.o
      ${lib.optionalString final.compiledNumastat "rm -f numastat"}
      export LDFLAGS="-Wl,-rpath,$out/lib"
      ${make} libnuma.so ${lib.optionalString final.installedInterface.static "libnuma.a"}
      # Older memhog targets do not depend on the linked libnuma.so.
      ${make} ${lib.escapeShellArgs programs} ${lib.optionalString final.compiledNumastat "numastat"}
    '')
    (command "numactl.install" ''
      mkdir -p "$out/bin" "$out/lib" "$out/include"
      install -m755 ${lib.escapeShellArgs (programs ++ [ "numastat" ])} "$out/bin/"
      install -m755 libnuma.so.1 "$out/lib/"
      ln -s libnuma.so.1 "$out/lib/libnuma.so"
      ${lib.optionalString final.installedInterface.static ''install -m644 libnuma.a "$out/lib/"''}
      install -m644 numa.h numaif.h ${lib.optionalString final.compatibilityHeader "numacompat1.h"} "$out/include/"
      for page in *.[2358]; do
        install -Dm644 "$page" "$out/share/man/man''${page##*.}/$page"
      done
    '')
    (steps.split "numactl.finalize")
    (outputs.copyArtifacts { })
    (lib.optional (!final.compiledNumastat) (
      outputs.shebangs {
        paths = [ "bin/numastat" ];
        names = [ "perl" ];
        interpreter = "${tools.perl}/bin/perl";
      }
    ))
    (outputs.strip {
      paths = [
        "bin"
        "lib"
      ];
    })
    (lib.optional final.installedInterface.static (
      outputs.stripArchives { paths = [ "lib/libnuma.a" ]; }
    ))
    (outputs.rpaths {
      paths = [
        "bin"
        "lib"
      ];
      libraries = final.runtime.libraries;
    })
    (outputs.development { libraries = [ ]; })
    (outputs.checkPaths {
      paths = [
        "bin"
        "lib"
      ];
    })
  ];
  meta = {
    description = "Linux NUMA policy tools and library";
    homepage = "https://github.com/numactl/numactl";
    license = [
      lib.licenses.gpl2Only
      lib.licenses.lgpl21Only
    ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "numactl";
  };
}
