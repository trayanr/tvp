# Complete ordinary gawk procedure beginning at 4.1.4.
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
  python,
  binutils,
  patchelf,
  sed,
  grep,
  gawk,
  diffutils,
  findutils,
  xz,
  perl,
  checkLocales,
  localeProvider,
  gmp,
  mpfr,
  readline,
  ncurses,
  doCheck ? true,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "gawk.${name}";
      cwd = "source";
      run = ''
        export NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE -std=${final.cStandard}"
        ${run}
      '';
    };
  rpaths =
    {
      python,
      binutils,
      patchelf,
      base,
      paths,
      libraries,
      dlopenDirectories ? [ ],
      elfKinds ? null,
    }:
    {
      name = "output.rpaths";
      tools = [
        python
        binutils
        patchelf
      ];
      run = ''${python}/bin/python3 -B ${../../../libraries/ordinary-compression-rpaths.py} "$out" ${
        lib.escapeShellArg (
          builtins.toJSON {
            inherit paths dlopenDirectories elfKinds;
            libraries = lib.concatMap (
              p: (p.development or { }).libraryDirectories or [ "${lib.getLib p}/lib" ]
            ) libraries;
            baseDirectories = base.runtimeDirectories;
            readelf = "${binutils}/bin/readelf";
            patchelf = "${patchelf}/bin/patchelf";
          }
        )
      } ${../../../../lib/native-output}'';
    };

in
{
  pname = "gawk";
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
    python
    binutils
    patchelf
    sed
    grep
    gawk
    diffutils
    findutils
    xz
    perl
    checkLocales
    localeProvider
    gmp
    mpfr
    readline
    ncurses
    doCheck
    ;
  cStandard = "gnu17";
  configureCFlags = "-Wno-error=implicit-function-declaration";
  configureFlags = [ ];
  stripFlags = [
    "-S"
    "-p"
  ];
  dependencyProviders = {
    bash = final.bash;
    coreutils = final.coreutils;
    gnumake = final.gnumake;
    gnutar = final.gnutar;
    python = final.python;
    binutils = final.binutils;
    patchelf = final.patchelf;
    sed = final.sed;
    grep = final.grep;
    gawk = final.gawk;
    diffutils = final.diffutils;
    findutils = final.findutils;
    xz = final.xz;
    perl = final.perl;
    checkLocales = final.checkLocales;
    localeProvider = final.localeProvider;
    gmp = final.gmp;
    mpfr = final.mpfr;
    readline = final.readline;
    ncurses = final.ncurses;
  };
  environment = {
    tools = [
      final.localeProvider
      final.gnumake
      final.sed
      final.grep
      final.gawk
      final.diffutils
      final.findutils
      final.perl
    ];
    libraries = [
      final.gmp
      final.mpfr
      final.readline
      final.ncurses
    ];
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
  runtime.libraries = [
    final.gmp
    final.mpfr
    final.readline
    final.ncurses
  ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.gnutar;
      xz = final.xz;
      findutils = final.findutils;
      compression = "xz";
    })
    (command "prepare" ''
      ${final.python}/bin/python3 -B ${../../ordinary-text-source.py} ${final.bash}/bin/bash ${final.perl}/bin/perl '${
        builtins.toJSON [
          "test"
          "awklib"
          "extension"
        ]
      }'
    '')
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash FORCE_UNSAFE_CONFIGURE=1
      export NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE ${final.configureCFlags}"
      ./configure --prefix="$out" ${lib.escapeShellArgs final.configureFlags} --enable-nls --with-readline=${final.readline} --with-mpfr=${final.mpfr}
      ${final.grep}/bin/grep '^#define HAVE_MPFR 1' config.h
      ${final.grep}/bin/grep '^#define HAVE_LIBREADLINE 1' config.h
      ${final.grep}/bin/grep '^#define ENABLE_NLS 1' config.h
    '')
    (command "build" ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'')
    (
      (command "check" ''
        export LOCPATH=${final.checkLocales} PAGER=cat
              ${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash check'')
      // {
        enabled = final.doCheck;
      }
    )
    (command "install" ''
      ${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
      cp config.h "$out/nix-support/config.h"
      ${final.grep}/bin/grep -Ex 'gt_cv_func_gnugettext[0-9]+_libc=yes' config.log > "$out/nix-support/gettext-libc"
    '')
    (steps.split "gawk.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "gawk.relocate";
      tools = [
        final.python
        final.binutils
        final.patchelf
      ];
      run = ''${final.python}/bin/python3 -B ${../../ordinary-text-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${final.patchelf}/bin/patchelf ${
        lib.escapeShellArg (
          builtins.toJSON {
            readelf = "${final.binutils}/bin/readelf";
            shell = "${final.runtime.shell}/bin/bash";
            buildShell = "${final.bash}/bin/bash";
            paths = map (p: "${p}/bin") final.runtime.tools;
          }
        )
      }'';
    }
    (outputs.shebangs {
      python = final.python;
      paths = [
        "bin"
        "lib"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.runtime.shell}/bin/bash";
    })
    (
      (outputs.shebangs {
        python = final.python;
        paths = [ "bin" ];
        names = [
          "awk"
          "gawk"
        ];
        selfInterpreter = "bin/gawk";
      })
      // {
        name = "output.awk-shebangs";
      }
    )
    (outputs.strip {
      flags = final.stripFlags;
      python = final.python;
      binutils = final.binutils;
      paths = [
        "bin"
        "lib"
      ];
    })
    (rpaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [
        "bin"
        "lib"
      ];
    })
    (outputs.development {
      python = final.python;
      libraries = [ ];
    })
    (outputs.checkPaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      paths = [
        "bin"
        "lib"
      ];
    })
  ];
  tvp.features = {
    bignum = true;
    nls = true;
  };
  tvp.readlineProgram = "gawk";
  meta = {
    description = "GNU AWK with arbitrary precision arithmetic";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
  };
}
