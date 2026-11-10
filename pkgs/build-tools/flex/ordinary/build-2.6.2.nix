# Flex 2.6.2–2.6.3 remove the K&R tests; 2.6.2 separately needs the man-page prerequisite patch.
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
  python,
  binutils,
  patchelf,
  bison,
  m4,
  file,
  patch,
  patches ? [ ],
  postPatch ? "",
  cStandard ? null,
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
    "bin"
    "lib"
  ];
in
{
  pname = "flex";
  checkCFlags = [ ];
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
    python
    binutils
    patchelf
    bison
    m4
    file
    configureFlags
    ;
  inherit
    patch
    patches
    postPatch
    cStandard
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
    python = final.python;
    binutils = final.binutils;
    patchelf = final.patchelf;
    bison = final.bison;
    m4 = final.m4;
    file = final.file;
    patch = final.patch;
  };
  environment = {
    tools = [
      final.gnumake
      final.sed
      final.grep
      final.gawk
      final.diffutils
      final.findutils
      final.bison
      final.m4
      final.file
    ];
    libraries = [ ];
    overrides.flags.NIX_CFLAGS_COMPILE = lib.optional (
      final.cStandard != null
    ) "-std=${final.cStandard}";
  };
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.gnutar;
      gzip = final.gzip;
      findutils = final.findutils;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "flex.prepare";
      bash = final.bash;
      python = final.python;
      base = final.base;
    })
    (steps.shebangs {
      name = "flex.test-shells";
      python = final.python;
      paths = [
        "tests"
        "build-aux"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (command "flex.patches" ''
      for patch in ${lib.escapeShellArgs (map (p: "${p}") final.patches)}; do
        ${final.patch}/bin/patch -p1 < "$patch"
      done
      ${final.postPatch}
    '')
    (command "flex.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" --enable-shared --enable-static M4=${final.m4}/bin/m4 ${lib.escapeShellArgs final.configureFlags}
    '')
    # The null-stream repair changes the emitter, not its CLI/manual. Rebuild
    # the shipped C skeleton explicitly before retaining the shipped manual's epoch.
    (command "flex.skeleton" ''
      ${make} -C src skel.c
      ${final.coreutils}/bin/touch -r doc/flex.1 src/flex.skl
    '')
    (command "flex.build" make)
    (command "flex.install" ''
      ${make} install
      ln -s flex "$out/bin/lex"
      test -s "$out/include/FlexLexer.h"
      test -s "$out/lib/libfl.a"
      test -s "$out/lib/libfl.la"
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')

    (steps.split "flex.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "flex.relocate";
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
      paths = [ "lib/libfl.a" ];
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
    (outputs.development {
      python = final.python;
      libraries = [ ];
    })
    (outputs.checkSymlinks {
      python = final.python;
      paths = [
        "lib/libfl.so"
        "lib/libfl.so.2"
        "bin/lex"
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
    homepage = "https://github.com/westes/flex";
    description = "Lexical analyser generator for C and C++";
    license = lib.licenses.bsd2;
    platforms = [ "x86_64-linux" ];
    mainProgram = "flex";
  };
}
