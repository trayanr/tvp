# File 5.45–5.47 retain libmagic, four codec providers and the compiled default magic database.
# Complete ordinary procedure; latest and frozen construction remain independently selected.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  gnumake,
  gnutar,
  gzip,
  findutils,
  sed,
  grep,
  gawk,
  diffutils,
  zlib,
  xz,
  bzip2,
  zstd,
  python,
  binutils,
  patchelf,
  configureFlags ? [ ],
}:
let
  inherit (tvp.builder) steps outputs;
in
final:
let
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      inherit name run;
      cwd = "source";
    };
  make = ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
  elfPaths = [
    "bin/file"
    "lib"
  ];
in
{
  pname = "file";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  inherit
    gnumake
    gnutar
    gzip
    findutils
    sed
    grep
    gawk
    diffutils
    zlib
    xz
    bzip2
    zstd
    python
    binutils
    patchelf
    configureFlags
    ;
  dependencyProviders = {
    bash = final.bash;
    coreutils = final.coreutils;
    gnumake = final.gnumake;
    gnutar = final.gnutar;
    gzip = final.gzip;
    findutils = final.findutils;
    sed = final.sed;
    grep = final.grep;
    gawk = final.gawk;
    diffutils = final.diffutils;
    zlib = final.zlib;
    xz = final.xz;
    bzip2 = final.bzip2;
    zstd = final.zstd;
    python = final.python;
    binutils = final.binutils;
    patchelf = final.patchelf;
  };
  environment = {
    tools = [
      final.gnumake
      final.sed
      final.grep
      final.gawk
      final.diffutils
      final.findutils
    ];
    libraries = [
      final.zlib
      final.xz
      final.bzip2
      final.zstd
    ];
  };
  runtime.libraries = [
    final.zlib
    final.xz
    final.bzip2
    final.zstd
  ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.gnutar;
      gzip = final.gzip;
      findutils = final.findutils;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "file.prepare";
      bash = final.bash;
      python = final.python;
      base = final.base;
    })
    (command "file.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" --enable-zlib --enable-bzlib --enable-xzlib --enable-zstdlib --enable-static --enable-shared ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "file.build" make)
    (command "file.install" ''
      ${make} install
      test -s "$out/share/misc/magic.mgc"
      test -s "$out/include/magic.h"
      test -s "$out/lib/pkgconfig/libmagic.pc"
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "file.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "file.relocate";
      tools = [ final.python ];
      run = ''
        ${final.python}/bin/python3 -B ${./relocate.py} "$out" "$TVP_ARTIFACT_ROOT" "${final.patchelf}/bin/patchelf"
      '';
    }
    (outputs.strip {
      python = final.python;
      binutils = final.binutils;
      paths = elfPaths;
    })
    (outputs.stripArchives {
      python = final.python;
      binutils = final.binutils;
      paths = [ "lib/libmagic.a" ];
    })
    (outputs.rpaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      base = final.base;
      paths = elfPaths;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
    })
    # Keep static libmagic's .la and private pkg-config compression requirements.
    (outputs.development {
      python = final.python;
      libraries = [
        final.zlib
        final.xz
        final.bzip2
        final.zstd
      ];
    })
    (outputs.checkSymlinks {
      python = final.python;
      paths = [
        "lib/libmagic.so"
        "lib/libmagic.so.1"
      ];
    })
    (outputs.checkPaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      paths = elfPaths;
    })
  ];
  meta = {
    description = "File type identification utility and libmagic";
    license = lib.licenses.bsd2;
    platforms = lib.platforms.unix;
    mainProgram = "file";
  };
}
