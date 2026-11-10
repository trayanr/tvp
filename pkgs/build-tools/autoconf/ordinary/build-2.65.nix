# Complete ordinary procedure for autoconf 2.65; installed output repair follows the artifact split.
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
  tvp.ordinaryAutotools = true;
  autoconfFrontend = "shell";
  pname = "autoconf";
  inherit
    base
    src
    version
    m4
    perl
    bash
    coreutils
    gnumake
    gnutar
    gzip
    findutils
    sed
    grep
    gawk
    diffutils
    python
    configureFlags
    ;
  dependencyProviders = {
    m4 = final.m4;
    perl = final.perl;
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
  };
  environment = {
    tools = [
      final.perl
      final.m4
      final.gnumake
      final.sed
      final.grep
      final.gawk
      final.diffutils
      final.findutils
    ];
    libraries = [ ];
  };
  runtime = {
    perl = final.perl;
    shell = final.bash;
    m4 = final.m4;
    tools = [
      final.coreutils
      final.sed
      final.grep
      final.bash
    ];
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.gnutar;
      gzip = final.gzip;
      findutils = final.findutils;
      compression = "gzip";
    })
    {
      name = "autoconf.source-confinement";
      cwd = "source";
      tools = [ final.python ];
      run = ''${final.python}/bin/python3 -B ${../../ordinary-autotools-source.py}'';
    }
    (steps.prepareAutotools {
      name = "autoconf.prepare";
      bash = final.bash;
      python = final.python;
      base = final.base;
    })
    (command "autoconf.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" PERL=${final.perl}/bin/perl M4=${final.m4}/bin/m4 ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "autoconf.build" ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'')
    (command "autoconf.install" ''
      ${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"

    '')
    (steps.split "autoconf.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "autoconf.relocate-runtime";
      tools = [ final.python ];
      run = ''${final.python}/bin/python3 -B ${../../ordinary-autotools-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        lib.escapeShellArg (
          builtins.toJSON {
            family = final.pname;
            perl = "${final.runtime.perl}/bin/perl";
            frontends = {
              autoconf = final.autoconfFrontend;
              autoheader = "perl";
              autom4te = "perl";
              autoreconf = "perl";
              autoscan = "perl";
              autoupdate = "perl";
              ifnames = "perl";
            };
            shell = "${final.runtime.shell}/bin/bash";
            paths = map (p: "${p}/bin") final.runtime.tools;
            replacements = [
              {
                old = "${final.perl}";
                new = "${final.runtime.perl}";
              }
              {
                old = "${final.m4}";
                new = "${final.runtime.m4}";
              }
            ];
          }
        )
      }'';
    }
    (outputs.shebangs {
      python = final.python;
      paths = [ "bin" ];
      names = [ "perl" ];
      interpreter = "${final.runtime.perl}/bin/perl";
    })
    (
      (outputs.shebangs {
        python = final.python;
        paths = [ "share/autoconf" ];
        names = [
          "sh"
          "bash"
        ];
        interpreter = "${final.runtime.shell}/bin/bash";
      })
      // {
        name = "output.shell-helpers";
      }
    )

  ];

  meta = {
    description = "Tool for producing configure scripts for building software";
    homepage = "https://www.gnu.org/software/autoconf/";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
    mainProgram = "autoconf";
  };
  tvp.features = {
    modernInit = true;
    consumerCStandard = null;
  };
}
