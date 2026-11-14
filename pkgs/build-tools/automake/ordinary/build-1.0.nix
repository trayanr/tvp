# Automake 1.0: no aclocal command, unsuffixed data and environment configure bindings.
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
  gzip,
  bzip2,
  xz,
  patch,
  findutils,
  sed,
  grep,
  gawk,
  diffutils,
  python,
  archiveExt ? "tar.xz",
  patches ? [ ],
  installAclocalDir ? false,
  headerMacro ? "AC_CONFIG_HEADERS",
  automaticCcCo ? true,
  hasAclocal ? true,
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
  tvp.historicalAutotools = true;
  pname = "automake";
  inherit
    base
    src
    version
    autoconf
    perl
    bash
    coreutils
    gnumake
    gnutar
    gzip
    bzip2
    xz
    patch
    findutils
    sed
    grep
    gawk
    diffutils
    python
    archiveExt
    patches
    installAclocalDir
    headerMacro
    automaticCcCo
    hasAclocal
    configureFlags
    ;
  dependencyProviders = {
    autoconf = final.autoconf;
    perl = final.perl;
    bash = final.bash;
    coreutils = final.coreutils;
    gnumake = final.gnumake;
    gnutar = final.gnutar;
    gzip = final.gzip;
    bzip2 = final.bzip2;
    xz = final.xz;
    patch = final.patch;
    findutils = final.findutils;
    sed = final.sed;
    grep = final.grep;
    gawk = final.gawk;
    diffutils = final.diffutils;
    python = final.python;
  };
  apiVersion = lib.versions.majorMinor final.version;
  environment = {
    tools = [
      final.perl
      final.autoconf
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
    tools = [
      final.coreutils
      final.sed
      final.grep
      final.bash
    ];
  };
  plan = steps.sequence [
    {
      name = "source.unpack";
      tools = [
        final.gnutar
        final.gzip
        final.bzip2
        final.xz
        final.findutils
      ];
      run = ''
        mkdir source
        ${final.gnutar}/bin/tar --use-compress-program=${
          if final.archiveExt == "tar.bz2" then
            "${final.bzip2}/bin/bzip2"
          else if final.archiveExt == "tar.xz" then
            "${final.xz}/bin/xz"
          else
            "${final.gzip}/bin/gzip"
        } -xf ${final.src} --strip-components=1 -C source
        chmod -R u+w source
        epoch=$(${final.findutils}/bin/find source -type f -not -newer "$NIX_BUILD_TOP/.." -printf '%T@\n' | sort -n | tail -n1)
        epoch=''${epoch%%.*}
        if (( ''${epoch:-0} < 315532800 )); then epoch=315532800; fi
        printf '%s\n' "$epoch" > source-date-epoch
      '';
    }
    {
      name = "automake.source-confinement";
      cwd = "source";
      tools = [ final.python ];
      run = ''${final.python}/bin/python3 -B ${../../ordinary-autotools-source.py}'';
    }
    (steps.prepareAutotools {
      name = "automake.prepare";
      bash = final.bash;
      python = final.python;
      base = final.base;
    })
    (command "automake.patches" ''
      :
      ${lib.concatMapStringsSep "\n" (p: "${final.patch}/bin/patch -p1 < ${p}") final.patches}
    '')
    (command "automake.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      export PERL=${final.perl}/bin/perl AUTOCONF=${final.autoconf}/bin/autoconf
      export AUTOM4TE=${final.autoconf}/bin/autom4te AUTORECONF=${final.autoconf}/bin/autoreconf
      export AUTOHEADER=${final.autoconf}/bin/autoheader AUTOUPDATE=${final.autoconf}/bin/autoupdate
      ./configure --prefix="$out" ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "automake.build" ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'')
    (command "automake.install" ''
      ${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
      ${lib.optionalString final.installAclocalDir ''mkdir -p "$out/share/aclocal"''}
      cp ${../setup-hook.sh} "$out/nix-support/setup-hook"
    '')
    (steps.split "automake.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "automake.relocate-runtime";
      tools = [ final.python ];
      run = ''${final.python}/bin/python3 -B ${../../historical-autotools-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        lib.escapeShellArg (
          builtins.toJSON {
            family = final.pname;
            perl = "${final.runtime.perl}/bin/perl";
            frontends = {
              automake = "perl";
              aclocal = "perl";
            };
            shell = "${final.runtime.shell}/bin/bash";
            paths = map (p: "${p}/bin") final.runtime.tools;
            replacements = [
              {
                old = "${final.perl}";
                new = "${final.runtime.perl}";
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
        paths = [ "share/automake" ];
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
  buildEnvironment = import ../build-environment.nix;
  meta = {
    description = "GNU Makefile generator and aclocal macro collector";
    homepage = "https://www.gnu.org/software/automake/";
    license = lib.licenses.gpl2Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "automake";
  };
  tvp.headerMacro = final.headerMacro;
  tvp.features = {
    automaticCcCo = final.automaticCcCo;
    aclocal = final.hasAclocal;
  };
}
