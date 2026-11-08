# Ordinary 5.48 only: owned commands and explicit compression/output policy.
# One prefix keeps the compiled default magic database path coherent with edits.
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
  make = ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
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
  environment = {
    tools = [
      gnumake
      sed
      grep
      gawk
      diffutils
      findutils
    ];
    libraries = [
      zlib
      xz
      bzip2
      zstd
    ];
  };
  runtime.libraries = [
    zlib
    xz
    bzip2
    zstd
  ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit gzip findutils;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "file.prepare";
      bash = final.bash;
      inherit python;
      base = final.base;
    })
    (command "file.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" --enable-zlib --enable-bzlib --enable-xzlib --enable-zstdlib --enable-static --enable-shared ${lib.escapeShellArgs configureFlags}
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
    (outputs.strip {
      inherit python binutils;
      paths = elfPaths;
    })
    (outputs.stripArchives {
      inherit python binutils;
      paths = [ "lib/libmagic.a" ];
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      paths = elfPaths;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
    })
    # Keep static libmagic's .la and private pkg-config compression requirements.
    (outputs.development {
      inherit python;
      libraries = [
        zlib
        xz
        bzip2
        zstd
      ];
    })
    (outputs.checkSymlinks {
      inherit python;
      paths = [
        "lib/libmagic.so"
        "lib/libmagic.so.1"
      ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = elfPaths;
    })
  ];
  meta = {
    description = "File type identification utility and libmagic";
    license = lib.licenses.bsd2;
    platforms = [ "x86_64-linux" ];
    mainProgram = "file";
  };
}
