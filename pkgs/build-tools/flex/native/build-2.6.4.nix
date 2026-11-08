# Ordinary 2.6.4 onward: independent owned procedure with shipped generated
# sources and configure files. Historical/bootstrap procedures remain separate.
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
  m4,
  file,
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
    "bin"
    "lib"
  ];
in
{
  pname = "flex";
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
      m4
      file
    ];
    libraries = [ ];
  };
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit gzip findutils;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "flex.prepare";
      bash = final.bash;
      inherit python;
      base = final.base;
    })
    (command "flex.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" --enable-shared --enable-static M4=${m4}/bin/m4 ${lib.escapeShellArgs configureFlags}
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

    (outputs.strip {
      inherit python binutils;
      paths = elfPaths;
    })
    (outputs.stripArchives {
      inherit python binutils;
      paths = [ "lib/libfl.a" ];
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      paths = elfPaths;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
    })
    (outputs.development {
      inherit python;
      libraries = [ ];
    })
    (outputs.checkSymlinks {
      inherit python;
      paths = [
        "lib/libfl.so"
        "lib/libfl.so.2"
        "bin/lex"
      ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = elfPaths;
    })
  ];
  meta = {
    description = "Lexical analyser generator for C and C++";
    license = lib.licenses.bsd2;
    platforms = [ "x86_64-linux" ];
    mainProgram = "flex";
  };
}
