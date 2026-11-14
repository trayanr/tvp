# Libtool 1.5.26: root ltmain.sh and configure argument bindings, before LT_INIT.
{
  tvp,
  lib,
  base,
  src,
  version,
  autoconf,
  automake,
  m4,
  file,
  patches ? [ ],
  configureFlags ? [ ],
  doCheck ? true,
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  checkpoint = "nix-support/libtool-build-tree";
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      inherit name run;
      cwd = "source";
    };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'';
  elfPaths = [ "lib" ];
in
{
  tvp.ordinaryAutotools = true;
  tvp.historicalAutotools = true;
  pname = "libtool";
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    autoconf
    automake
    m4
    file
    configureFlags
    patches
    doCheck
    ;
  inherit (tools) bash coreutils;
  dependencyProviders = {
    autoconf = final.autoconf;
    automake = final.automake;
    m4 = final.m4;
    file = final.file;
  };
  sourceLayout = "root-ltmain-configure-arguments";
  installedInterface = {
    auxiliaryDirectory = "share/libtool";
    knownFrontends = false;
  };
  environment = {
    tools = [
      final.autoconf
      final.automake
      final.m4
      final.file
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
    shell = tools.bash;
    tools = [
      tools.gnutar
      tools.coreutils
      tools.sed
      tools.grep
      tools.gawk
      tools.bash
      final.autoconf
      final.automake
      final.m4
      final.file
    ];
    libraries = [ ];
  };
  productionPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (command "libtool.patches" ''
      :
      ${lib.concatMapStringsSep "\n" (p: "${tools.patch}/bin/patch -p1 < ${p}") final.patches}
    '')
    (command "libtool.template" ''chmod +x libtoolize.in'')
    (steps.shebangs {
      name = "libtool.source-interpreter";
      paths = [
        "libtoolize.in"
      ];
      names = [ "sh" ];
      interpreter = "${tools.bash}/bin/bash";
    })
    {
      name = "libtool.source-confinement";
      cwd = "source";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../ordinary-autotools-source.py}'';
    }
    (steps.prepareAutotools {
      name = "libtool.prepare";
    })
    (command "libtool.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash
      ./configure --prefix="$out" --enable-shared --enable-static M4=${final.m4}/bin/m4 FILECMD=${final.file}/bin/file ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "libtool.build" make)
    (command "libtool.install" ''
      ${make} install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (command "libtool.save-build-tree" ''
      ${tools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/${checkpoint}"
    '')
  ];
  upstreamPlan = artifact: [
    {
      name = "libtool.restore-build-tree";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${./tests/restore.py} ${artifact}/${checkpoint} "$TVP_SOURCE_ROOT"'';
    }
  ];
  upstreamCheck =
    (command "libtool.check" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash
      status=0
      ${make} check || status=$?
      ${tools.findutils}/bin/find . -name '*suite.log' -exec ${tools.coreutils}/bin/cat {} \; >&2
      exit "$status"
    '')
    // {
      enabled = final.doCheck;
    };
  plan = final.productionPlan ++ [
    (steps.split "libtool.finalize")
    (outputs.copyArtifacts { })
    {
      name = "libtool.drop-build-tree";
      tools = [ tools.coreutils ];
      run = ''${tools.coreutils}/bin/rm -rf -- "$out/${checkpoint}"'';
    }
    {
      name = "libtool.relocate-runtime";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../historical-autotools-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        lib.escapeShellArg (
          builtins.toJSON {
            family = final.pname;
            frontends = {
              libtool = "shell";
              libtoolize = "shell";
            };
            shell = "${final.runtime.shell}/bin/bash";
            paths = map (p: "${p}/bin") final.runtime.tools;
            replacements = [
              {
                old = "${tools.bash}/bin/bash";
                new = "${final.runtime.shell}/bin/bash";
              }
            ];
          }
        )
      }'';
    }
    (outputs.shebangs {
      paths = [
        "bin"
        "share/libtool"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.runtime.shell}/bin/bash";
    })

    (outputs.strip {
      paths = elfPaths;
    })
    (outputs.stripArchives {
      paths = [ "lib/libltdl.a" ];
    })
    (outputs.rpaths {
      paths = elfPaths;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
    })
    # libltdl's shared/static interface, .la file and installed aliases are retained.
    (outputs.development {
      libraries = [ ];
    })
    (outputs.checkPaths {
      paths = elfPaths;
    })
  ];
  development = package: { aclocalDirectories = [ "${package}/share/aclocal" ]; };
  tvp.features = {
    toolDefaults = false;
    cxxDependencyTracking = true;
    acLibtool = true;
    ltdl = true;
    ltInit = false;
    consumerCStandard = null;
  };
  meta = {
    homepage = "https://www.gnu.org/software/libtool/";
    description = "GNU portable library build tools and libltdl loader library";
    license = [
      lib.licenses.gpl2Plus
      lib.licenses.lgpl2Plus
    ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "libtool";
  };
}
