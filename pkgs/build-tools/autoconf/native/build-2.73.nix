# 2.73 only: owned commands replace setup-hook construction. The shipped
# configure/Makefiles avoid a production Autoconf/Automake regeneration cycle.
# Installed Perl programs embed data and sibling paths, so keep one prefix/stage.
{
  tvp,
  lib,
  base,
  src,
  version,
  m4,
  perl,
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
  pname = "autoconf";
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
      m4
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
      inherit gzip findutils;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "autoconf.prepare";
      bash = final.bash;
      inherit python;
      base = final.base;
    })
    (command "autoconf.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" PERL=${final.runtime.perl}/bin/perl M4=${m4}/bin/m4 ${lib.escapeShellArgs configureFlags}
    '')
    (command "autoconf.build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'')
    (command "autoconf.install" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"

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
        paths = [ "share/autoconf/build-aux" ];
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
      name = "autoconf.runtime-tools";
      tools = [ python ];
      run = ''${python}/bin/python3 -B ${../../autotools-runtime.py} "$out" ${
        lib.escapeShellArg (builtins.toJSON (map (t: "${t}/bin") final.runtime.tools))
      } ${
        lib.escapeShellArgs [
          "autoconf"
          "autoheader"
          "autom4te"
          "autoreconf"
          "autoscan"
          "autoupdate"
          "ifnames"
        ]
      }'';
    }
  ];

  meta = {
    description = "Tool for producing configure scripts for building software";
    homepage = "https://www.gnu.org/software/autoconf/";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "autoconf";
  };
  tvp.features = {
    modernInit = true;
    consumerCStandard = null;
  };
}
