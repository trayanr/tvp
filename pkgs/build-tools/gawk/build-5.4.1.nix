# Native ordinary 5.4.1 boundary: complete source-GNU procedure for 5.4.1 only.
# Earlier releases and captured construction generations retain independent routes.
{
  tvp,
  lib,
  base,
  src,
  version,
  gmp,
  mpfr,
  readline,
  ncurses,
  doCheck ? true,
}:

final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;

  checkpoint = "nix-support/gawk-build-tree";
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
  bash = tools.bash;
  inherit doCheck;
  inherit mpfr;
  inherit gmp;
  inherit ncurses;
  inherit readline;
  inherit (tools) coreutils;
  # Equal-width compiled-prefix ABI; the artifact remains a distinct producer.
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    ;
  dependencyProviders = {
    gmp = final.gmp;
    mpfr = final.mpfr;
    readline = final.readline;
    ncurses = final.ncurses;
  };
  environment = {
    tools = [
      tools.gnumake
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
      tools.perl
    ];
    libraries = [
      final.gmp
      final.mpfr
      final.readline
      final.ncurses
    ];
  };
  runtime.libraries = [
    final.gmp
    final.mpfr
    final.readline
    final.ncurses
  ];

  installedInterface = {
    ordinaryControls = false;
    hasNls = true;
  };
  upstreamPlan = artifact: [
    {
      name = "gawk.restore-build-tree";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../text-tool-restore.py} ${artifact}/${checkpoint} "$TVP_SOURCE_ROOT"'';
    }

    {
      name = "gawk.upstream-frontends";
      tools = [
        tools.python
        tools.perl
      ];
      run = ''
        cd "$(cat "$TVP_SOURCE_ROOT/tree-path")"
        ${tools.python}/bin/python3 -B ${../ordinary-text-upstream-source.py} ${final.bash}/bin/bash ${tools.perl}/bin/perl '${builtins.toJSON [ "test" ]}'
      '';
    }
  ];
  upstreamCheck =
    (command "check" ''
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash check
    '')
    // {
      enabled = final.doCheck;
    };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;

      compression = "xz";
    })
    (steps.prepareAutotools {
      name = "gawk.prepare";

      base = final.base;
    })
    (steps.shebangs {
      name = "gawk.source-shells";

      paths = [
        "build-aux"
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
      ./configure --prefix="$out" --enable-nls --with-readline=${final.readline} --with-mpfr=${final.mpfr} --with-gmp=${final.gmp}
      grep '^#define HAVE_MPFR 1' config.h
      grep '^#define HAVE_LIBREADLINE 1' config.h
      grep '^#define ENABLE_NLS 1' config.h
    '')
    (command "build" ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'')
    (command "install" ''
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
      cp config.h "$out/nix-support/config.h"
      grep -Ex 'gt_cv_func_gnugettext[0-9]+_libc=yes' config.log > "$out/nix-support/gettext-libc"
    '')

    {
      name = "gawk.save-build-tree";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/${checkpoint}"'';
    }
    (steps.split "gawk.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "gawk.drop-build-tree";
      tools = [ tools.coreutils ];
      run = ''${tools.coreutils}/bin/rm -rf -- "$out/${checkpoint}"'';
    }

    {
      name = "gawk.relocate";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../owned-split-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        lib.escapeShellArg (
          builtins.toJSON {
            text = [ ];
            slots = [ ];
            fixed = [ ];
          }
        )
      } ${../../../lib/installed-tree.py}'';
    }
    (outputs.shebangs {
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
      paths = [
        "bin"
        "lib"
      ];
    })
    (outputs.rpaths {
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [
        "bin"
        "lib"
      ];
    })
    (outputs.development {
      libraries = [ ];
    })
    (outputs.checkPaths {
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
