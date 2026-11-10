# Complete ordinary procedure for automake 1.12; installed output repair follows the artifact split.
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
  tvp.ordinaryAutotools = true;
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
    xz
    findutils
    sed
    grep
    gawk
    diffutils
    python
    configureFlags
    ;
  dependencyProviders = {
    autoconf = final.autoconf;
    perl = final.perl;
    bash = final.bash;
    coreutils = final.coreutils;
    gnumake = final.gnumake;
    gnutar = final.gnutar;
    xz = final.xz;
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
    (steps.unpack {
      src = final.src;
      tar = final.gnutar;
      xz = final.xz;
      findutils = final.findutils;
      compression = "xz";
    })
    (steps.prepareAutotools {
      name = "automake.prepare";
      bash = final.bash;
      python = final.python;
      base = final.base;
    })
    {
      name = "automake.api";
      cwd = "source";
      tools = [ final.python ];
      run = ''${final.python}/bin/python3 -B ${./prepare-api.py} ${
        lib.escapeShellArgs [
          final.version
          final.apiVersion
        ]
      }'';
    }
    (command "automake.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" PERL=${final.perl}/bin/perl AUTOCONF=${final.autoconf}/bin/autoconf AUTOM4TE=${final.autoconf}/bin/autom4te AUTORECONF=${final.autoconf}/bin/autoreconf AUTOHEADER=${final.autoconf}/bin/autoheader AUTOUPDATE=${final.autoconf}/bin/autoupdate ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "automake.build" ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'')
    (command "automake.install" ''
      ${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
      cp ${../setup-hook.sh} "$out/nix-support/setup-hook"
    '')
    (steps.split "automake.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "automake.relocate-runtime";
      tools = [ final.python ];
      run = ''${final.python}/bin/python3 -B ${../../ordinary-autotools-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        lib.escapeShellArg (
          builtins.toJSON {
            family = final.pname;
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
    {
      name = "automake.aliases";
      tools = [ final.coreutils ];
      run = ''
        # Upstream installs hardlinked aliases. Relative symlinks keep explicit
        # interpreter/runtime edits coherent on both command names.
        ln -sf automake "$out/bin/automake-${final.apiVersion}"
        ln -sf aclocal "$out/bin/aclocal-${final.apiVersion}"
      '';
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
        paths = [ "share/automake-${final.apiVersion}" ];
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

    (outputs.checkSymlinks {
      python = final.python;
      paths = [
        "bin/automake-${final.apiVersion}"
        "bin/aclocal-${final.apiVersion}"
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
