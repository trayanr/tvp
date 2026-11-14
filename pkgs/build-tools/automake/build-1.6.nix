# Complete Automake 1.6 procedure. API-suffixed data with declared configure arguments.
{
  tvp,
  lib,
  base,
  src,
  version,
  autoconf,
  perl,
  patches ? [ ],
  configureFlags ? [ ],
  doCheck ? true,
  buildFeatures ? { },
  sourceLayout ? { },
  installedInterface ? { },
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  environment = final.base.environment final.environment;
  command =
    name: run:
    environment
    // {
      inherit name run;
      cwd = "source";
    };
  checkpoint = "nix-support/automake-build-tree";
in
{
  pname = "automake";
  inherit
    base
    src
    version
    autoconf
    perl
    patches
    configureFlags
    doCheck
    ;
  inherit (tools) bash coreutils;
  apiVersion = lib.versions.majorMinor final.version;
  buildFeatures = {
    automaticCcCo = true;
    installAclocalDirectory = false;
  } // buildFeatures;
  sourceLayout = {
    archiveExt = "tar.bz2";
    compression =
      if final.sourceLayout.archiveExt == "tar.bz2" then
        "bzip2"
      else if final.sourceLayout.archiveExt == "tar.xz" then
        "xz"
      else if final.sourceLayout.archiveExt == "tar.gz" then
        "gzip"
      else
        throw "Automake: unsupported declared archive extension ${final.sourceLayout.archiveExt}";
  } // sourceLayout;
  installedInterface = {
    dataDirectory = "share/automake-${final.apiVersion}";
    versionedAliases = true;
    configuredApi = false;
    headerMacro = "AC_CONFIG_HEADERS";
    aclocal = true;
  } // installedInterface;
  environment = {
    tools = [
      final.perl
      final.autoconf
      tools.gnumake
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
    ];
    libraries = [ ];
  };
  runtime = {
    perl = final.perl;
    shell = tools.bash;
    tools = [
      tools.coreutils
      tools.sed
      tools.grep
      tools.bash
    ];
  };
  productionPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = final.sourceLayout.compression;
    })
    {
      name = "automake.source-confinement";
      cwd = "source";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../ordinary-autotools-source.py}'';
    }
    (steps.prepareAutotools { name = "automake.prepare"; })
    (
      (command "automake.patches" ''
        :
        ${lib.concatMapStringsSep "\n" (p: "${tools.patch}/bin/patch -p1 < ${p}") final.patches}
      '')
      // {
        tools = environment.tools ++ [ tools.patch ];
      }
    )
    (command "automake.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash
      ./configure --prefix="$out" PERL=${final.perl}/bin/perl AUTOCONF=${final.autoconf}/bin/autoconf AUTOM4TE=${final.autoconf}/bin/autom4te AUTORECONF=${final.autoconf}/bin/autoreconf AUTOHEADER=${final.autoconf}/bin/autoheader AUTOUPDATE=${final.autoconf}/bin/autoupdate ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "automake.build" ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'')
    (command "automake.install" ''
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
      ${lib.optionalString final.buildFeatures.installAclocalDirectory ''mkdir -p "$out/share/aclocal"''}
      cp ${./setup-hook.sh} "$out/nix-support/setup-hook"
    '')
    (
      (command "automake.save-build-tree" ''
        ${tools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/${checkpoint}"
      '')
      // {
        tools = environment.tools ++ [ tools.python ];
      }
    )
  ];
  upstreamPlan = artifact: [
    {
      name = "automake.restore-build-tree";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${./tests/restore.py} ${artifact}/${checkpoint} "$TVP_SOURCE_ROOT"'';
    }
  ];
  upstreamCheck =
    (command "automake.check" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash
      export AM_TESTSUITE_AUTOCONF=autoconf AM_TESTSUITE_AUTOHEADER=autoheader
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL="$CONFIG_SHELL" check
    '')
    // {
      enabled = final.doCheck;
    };
  plan = final.productionPlan ++ [
    (steps.split "automake.finalize")
    (outputs.copyArtifacts { })
    {
      name = "automake.drop-build-tree";
      tools = [ tools.coreutils ];
      run = ''${tools.coreutils}/bin/rm -rf -- "$out/${checkpoint}"'';
    }
    {
      name = "automake.relocate-runtime";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../historical-autotools-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${
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
    {
      name = "automake.aliases";
      tools = [ tools.coreutils ];
      run = ''
        ln -sf automake "$out/bin/automake-${final.apiVersion}"
        ln -sf aclocal "$out/bin/aclocal-${final.apiVersion}"
      '';
    }
    (outputs.shebangs {
      paths = [ "bin" ];
      names = [ "perl" ];
      interpreter = "${final.runtime.perl}/bin/perl";
    })
    (
      (outputs.shebangs {
        paths = [ final.installedInterface.dataDirectory ];
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
      paths = [
        "bin/automake-${final.apiVersion}"
        "bin/aclocal-${final.apiVersion}"
      ];
    })
  ];
  buildEnvironment = import ./build-environment.nix;
  meta = {
    description = "GNU Makefile generator and aclocal macro collector";
    homepage = "https://www.gnu.org/software/automake/";
    license = lib.licenses.gpl2Plus;
    mainProgram = "automake";
  };
  tvp.headerMacro = final.installedInterface.headerMacro;
  tvp.features = {
    automaticCcCo = final.buildFeatures.automaticCcCo;
    aclocal = final.installedInterface.aclocal;
    configuredApi = final.installedInterface.configuredApi;
  };
}
