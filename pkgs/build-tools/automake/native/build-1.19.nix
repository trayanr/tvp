# 1.19 only: owned commands replace setup-hook construction. The shipped
# configure/Makefiles avoid a production Autoconf/Automake regeneration cycle.
# Installed Perl programs embed data and sibling paths, so keep one prefix/stage.
{
  tvp,
  lib,
  base,
  src,
  version,
  autoconf,
  perl,
  bash,
  coreutils,
  gnumake,
  gnutar,
  xz,
  findutils,
  sed,
  grep,
  gawk,
  diffutils,
  python,
  configureFlags ? [ ],
}:
let
  inherit (tvp.builder) steps outputs;
in
final:
let
  environment = final.base.environment final.environment;
  command =
    name: run:
    environment
    // {
      inherit name run;
      cwd = "source";
    };
in
{
  pname = "automake";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  environment = {
    tools = [
      perl
      autoconf
      gnumake
      sed
      grep
      gawk
      diffutils
      findutils
    ];
    libraries = [ ];
  };
  runtime = {
    inherit perl;
    tools = [
      coreutils
      sed
      grep
      bash
    ];
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit xz findutils;
      compression = "xz";
    })
    (steps.prepareAutotools {
      name = "automake.prepare";
      bash = final.bash;
      inherit python;
      base = final.base;
    })
    (command "automake.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" PERL=${final.runtime.perl}/bin/perl AUTOCONF=${autoconf}/bin/autoconf AUTOM4TE=${autoconf}/bin/autom4te AUTORECONF=${autoconf}/bin/autoreconf AUTOHEADER=${autoconf}/bin/autoheader AUTOUPDATE=${autoconf}/bin/autoupdate ${lib.escapeShellArgs configureFlags}
    '')
    (command "automake.build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'')
    (command "automake.install" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash install
      # Upstream installs hardlinked aliases. Relative symlinks keep explicit
      # interpreter/runtime edits coherent on both command names.
      ln -sf automake "$out/bin/automake-1.19"
      ln -sf aclocal "$out/bin/aclocal-1.19"
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
      cp ${../setup-hook.sh} "$out/nix-support/setup-hook"
    '')
    (outputs.shebangs {
      inherit python;
      paths = [ "bin" ];
      names = [ "perl" ];
      interpreter = "${final.runtime.perl}/bin/perl";
    })
    (
      (outputs.shebangs {
        inherit python;
        paths = [ "share/automake-1.19" ];
        names = [
          "sh"
          "bash"
        ];
        interpreter = "${final.bash}/bin/bash";
      })
      // {
        name = "output.shell-helpers";
      }
    )
    {
      name = "automake.runtime-tools";
      tools = [ python ];
      run = ''${python}/bin/python3 -B ${../../autotools-runtime.py} "$out" ${
        lib.escapeShellArg (builtins.toJSON (map (t: "${t}/bin") final.runtime.tools))
      } ${
        lib.escapeShellArgs [
          "automake"
          "aclocal"
        ]
      }'';
    }
    (outputs.checkSymlinks {
      inherit python;
      paths = [
        "bin/automake-1.19"
        "bin/aclocal-1.19"
      ];
    })
  ];
  buildEnvironment = import ../build-environment.nix;
  meta = {
    description = "GNU Makefile generator and aclocal macro collector";
    homepage = "https://www.gnu.org/software/automake/";
    license = lib.licenses.gpl2Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "automake";
  };
  tvp.headerMacro = "AC_CONFIG_HEADERS";
  tvp.features = {
    automaticCcCo = true;
  };
}
