# Libtool 1.3.5–1.4.3: libltdl, pre-LT_INIT macros and environment configure bindings.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  autoconf,
  automake,
  platformAutomake,
  m4,
  file,
  patch,
  gnumake,
  gnutar,
  gzip,
  findutils,
  sed,
  grep,
  gawk,
  diffutils,
  python,
  binutils,
  patchelf,
  patches ? [ ],
  cStandard ? null,
  testFeatures ? { },
  license ? [
    lib.licenses.gpl2Plus
    lib.licenses.lgpl2Plus
  ],
  configureFlags ? [ ],
}:
let
  inherit (tvp.builder) steps outputs;
in
final:
let
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      inherit name run;
      cwd = "source";
    };
  make = ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
  elfPaths = [ "lib" ];
in
{
  tvp.ordinaryAutotools = true;
  tvp.historicalAutotools = true;
  pname = "libtool";
  inherit
    base
    src
    version
    bash
    coreutils
    autoconf
    automake
    platformAutomake
    m4
    file
    patch
    gnumake
    gnutar
    gzip
    findutils
    sed
    grep
    gawk
    diffutils
    python
    binutils
    patchelf
    cStandard
    testFeatures
    license
    configureFlags
    patches
    ;
  dependencyProviders = {
    bash = final.bash;
    coreutils = final.coreutils;
    autoconf = final.autoconf;
    automake = final.automake;
    platformAutomake = final.platformAutomake;
    m4 = final.m4;
    file = final.file;
    patch = final.patch;
    gnumake = final.gnumake;
    gnutar = final.gnutar;
    gzip = final.gzip;
    findutils = final.findutils;
    sed = final.sed;
    grep = final.grep;
    gawk = final.gawk;
    diffutils = final.diffutils;
    python = final.python;
    binutils = final.binutils;
    patchelf = final.patchelf;
  };
  environment = {
    tools = [
      final.autoconf
      final.automake
      final.m4
      final.file
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
    shell = final.bash;
    tools = [
      final.gnutar
      final.coreutils
      final.sed
      final.grep
      final.gawk
      final.bash
      final.autoconf
      final.automake
      final.m4
      final.file
    ];
    libraries = [ ];
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.gnutar;
      gzip = final.gzip;
      findutils = final.findutils;
      compression = "gzip";
    })
    (command "libtool.patches" ''
      :
      ${lib.concatMapStringsSep "\n" (p: "${final.patch}/bin/patch -p1 < ${p}") final.patches}
    '')
    (command "libtool.platform" ''
      cp ${final.platformAutomake}/share/automake-${lib.versions.majorMinor final.platformAutomake.version}/config.{guess,sub} .
    '')
    (command "libtool.template" ''chmod +x libtoolize.in'')
    (steps.shebangs {
      name = "libtool.source-interpreter";
      python = final.python;
      paths = [
        "libtoolize.in"
      ];
      names = [ "sh" ];
      interpreter = "${final.bash}/bin/bash";
    })
    {
      name = "libtool.source-confinement";
      cwd = "source";
      tools = [ final.python ];
      run = ''${final.python}/bin/python3 -B ${../../ordinary-autotools-source.py}'';
    }
    (steps.prepareAutotools {
      name = "libtool.prepare";
      bash = final.bash;
      python = final.python;
      base = final.base;
    })
    (command "libtool.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      export M4=${final.m4}/bin/m4 FILECMD=${final.file}/bin/file
      ${lib.optionalString (
        final.cStandard != null
      ) ''export CFLAGS="''${CFLAGS:--g -O2} -std=${final.cStandard}"''}
      ./configure --prefix="$out" --enable-shared --enable-static ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "libtool.build" make)
    (command "libtool.install" ''
      ${make} install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "libtool.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "libtool.relocate-runtime";
      tools = [ final.python ];
      run = ''${final.python}/bin/python3 -B ${../../historical-autotools-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${
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
                old = "${final.bash}/bin/bash";
                new = "${final.runtime.shell}/bin/bash";
              }
            ];
          }
        )
      }'';
    }
    (outputs.shebangs {
      python = final.python;
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
      python = final.python;
      binutils = final.binutils;
      paths = elfPaths;
    })
    (outputs.stripArchives {
      python = final.python;
      binutils = final.binutils;
      paths = [ "lib/libltdl.a" ];
    })
    (outputs.rpaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      paths = elfPaths;
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
    })
    # libltdl's shared/static interface, .la file and installed aliases are retained.
    (outputs.development {
      python = final.python;
      libraries = [ ];
    })
    (outputs.checkPaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      paths = elfPaths;
    })
  ];
  development = package: { aclocalDirectories = [ "${package}/share/aclocal" ]; };
  tvp.buildDeps.platformAutomake = final.platformAutomake;
  tvp.features = {
    toolDefaults = false;
    cxxDependencyTracking = false;
    acLibtool = true;
    ltdl = true;
    ltInit = false;
    consumerCStandard = final.cStandard;
  } // final.testFeatures;
  meta = {
    homepage = "https://www.gnu.org/software/libtool/";
    description = "GNU portable library build tools and libltdl loader library";
    license = final.license;
    platforms = [ "x86_64-linux" ];
    mainProgram = "libtool";
  };
}
