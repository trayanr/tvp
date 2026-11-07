# Native ordinary 5.4.1 boundary: complete source-GNU procedure for 5.4.1 only.
# Earlier releases and captured construction generations retain independent routes.
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
      inherit run;
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
  environment = {
    tools = [
      localeProvider
      gnumake
      sed
      grep
      gawk
      diffutils
      findutils
      perl
    ];
    libraries = [
      gmp
      mpfr
      readline
      ncurses
    ];
  };
  runtime.libraries = [
    gmp
    mpfr
    readline
    ncurses
  ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit xz findutils;
      compression = "xz";
    })
    (steps.prepareAutotools {
      name = "gawk.prepare";
      bash = final.bash;
      inherit python;
      base = final.base;
    })
    (steps.shebangs {
      name = "gawk.source-shells";
      inherit python;
      paths = [
        "build-aux"
        "test"
        "extension"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash FORCE_UNSAFE_CONFIGURE=1
      ./configure --prefix="$out" --enable-nls --with-readline=${readline} --with-mpfr=${mpfr} --with-gmp=${gmp}
      grep '^#define HAVE_MPFR 1' config.h
      grep '^#define HAVE_LIBREADLINE 1' config.h
      grep '^#define ENABLE_NLS 1' config.h
    '')
    (command "build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'')
    (
      (command "check" ''
        export LOCPATH=${checkLocales} PAGER=cat
              ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash check'')
      // {
        enabled = doCheck;
      }
    )
    (command "install" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
      cp config.h "$out/nix-support/config.h"
      grep -Ex 'gt_cv_func_gnugettext[0-9]+_libc=yes' config.log > "$out/nix-support/gettext-libc"
    '')
    (outputs.shebangs {
      inherit python;
      paths = [
        "bin"
        "lib"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (
      (outputs.shebangs {
        inherit python;
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
      inherit python binutils;
      paths = [
        "bin"
        "lib"
      ];
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [
        "bin"
        "lib"
      ];
    })
    (outputs.development {
      inherit python;
      libraries = [ ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
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
    platforms = [ "x86_64-linux" ];
  };
}
