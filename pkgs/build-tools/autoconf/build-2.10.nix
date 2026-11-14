# Complete Autoconf 2.10-era procedure, with independent upstream execution.
{
  tvp,
  lib,
  base,
  src,
  version,
  m4,
  perl,
  modernInit ? true,
  consumerCStandard ? null,
  configureFlags ? [ ],
  doCheck ? true,
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
  checkpoint = "nix-support/autoconf-build-tree";
in
{
  pname = "autoconf";
  inherit
    base
    src
    version
    m4
    perl
    configureFlags
    doCheck
    ;
  inherit modernInit consumerCStandard;
  inherit (tools) bash coreutils;
  installedInterface = {
    knownFrontends = false;
    frontends = {
      autoconf = "shipped";
      autoheader = "shipped";
      autom4te = "shipped";
      autoreconf = "shipped";
      autoscan = "shipped";
      autoupdate = "shipped";
      ifnames = "shipped";
    };
  };
  environment = {
    tools = [
      final.perl
      final.m4
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
    m4 = final.m4;
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
      compression = "gzip";
    })
    {
      name = "autoconf.source-confinement";
      cwd = "source";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../ordinary-autotools-source.py}'';
    }
    (steps.prepareAutotools { name = "autoconf.prepare"; })
    (command "autoconf.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash
      export PERL=${final.perl}/bin/perl M4=${final.m4}/bin/m4
      ./configure --prefix="$out" ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "autoconf.build" ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'')
    (command "autoconf.install" ''
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (
      (command "autoconf.save-build-tree" ''
        ${tools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/${checkpoint}"
      '')
      // {
        tools = environment.tools ++ [ tools.python ];
      }
    )
  ];
  upstreamPlan = artifact: [
    {
      name = "autoconf.restore-build-tree";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${./tests/restore.py} ${artifact}/${checkpoint} "$TVP_SOURCE_ROOT"'';
    }
  ];
  upstreamCheck =
    (command "autoconf.check" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL="$CONFIG_SHELL" check
    '')
    // {
      enabled = final.doCheck;
    };
  plan = final.productionPlan ++ [
    (steps.split "autoconf.finalize")
    (outputs.copyArtifacts { })
    {
      name = "autoconf.drop-build-tree";
      tools = [ tools.coreutils ];
      run = ''${tools.coreutils}/bin/rm -rf -- "$out/${checkpoint}"'';
    }
    {
      name = "autoconf.relocate-runtime";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../historical-autotools-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        lib.escapeShellArg (
          builtins.toJSON {
            family = final.pname;
            perl = "${final.runtime.perl}/bin/perl";
            frontends = final.installedInterface.frontends;
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
      paths = [ "bin" ];
      names = [ "perl" ];
      interpreter = "${final.runtime.perl}/bin/perl";
    })
    (
      (outputs.shebangs {
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
    license = lib.licenses.gpl2Plus;
    mainProgram = "autoconf";
  };
  tvp.features = {
    modernInit = final.modernInit;
    consumerCStandard = final.consumerCStandard;
  };
}
