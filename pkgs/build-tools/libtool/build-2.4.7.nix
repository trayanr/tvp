# Complete ordinary procedure for libtool 2.4.7; installed output repair follows the artifact split.
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
  additionalTemplates ? [ ],
  testGroups ? [
    1
    2
    3
    4
    5
    6
    7
    8
    9
    10
  ],
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
    additionalTemplates
    testGroups
    ;
  inherit (tools) bash coreutils;
  dependencyProviders = {
    autoconf = final.autoconf;
    automake = final.automake;
    m4 = final.m4;
    file = final.file;
  };
  sourceLayout = "build-aux-regenerated-ltmain";
  installedInterface = {
    auxiliaryDirectory = "share/libtool/build-aux";
    knownFrontends = true;
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
      compression = "xz";
    })
    (
      (command "libtool.patch" ''
        ${lib.concatMapStringsSep "\n" (p: "${tools.patch}/bin/patch -p1 < ${p}") final.patches}
        # Preserve shipped timestamps so adapted templates cannot trigger aclocal,
        # automake or help2man regeneration. Only ltmain.sh is explicitly rebuilt.
        for script in libtoolize.in build-aux/ltmain.in; do
          test "$(${tools.grep}/bin/grep -Fo '@TVP_AUTOCONF@' "$script" | ${tools.coreutils}/bin/wc -l)" = 1
          test "$(${tools.grep}/bin/grep -Fo '@TVP_AUTOMAKE@' "$script" | ${tools.coreutils}/bin/wc -l)" = 1
          cp -p "$script" "$script.timestamp"
          sed -i -e 's|@TVP_AUTOCONF@|${final.autoconf}/bin/autoconf|g' -e 's|@TVP_AUTOMAKE@|${final.automake}/bin/automake|g' "$script"
          touch -r "$script.timestamp" "$script"
          rm "$script.timestamp"
        done
        # Configure emits executable programs from non-executable templates.
        # Opt them into explicit interpreter preparation without changing mtime.
        chmod +x libtoolize.in ${lib.escapeShellArgs final.additionalTemplates}
      '')
      // {
        tools = [
          tools.patch
          tools.sed
        ];
      }
    )
    (steps.shebangs {
      name = "libtool.source-interpreter";
      paths = [
        "libtoolize.in"
      ] ++ final.additionalTemplates;
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
    (command "libtool.build" ''
      ${make} build-aux/ltmain.sh
      touch -r build-aux/ltmain.sh doc/libtool.1
      touch -r libtoolize.in doc/libtoolize.1
      ${make}
    '')
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
      ${make} TESTSUITEFLAGS="-j$NIX_BUILD_CORES ${
        lib.concatMapStringsSep " " toString final.testGroups
      }" check || status=$?
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
      run = ''${tools.python}/bin/python3 -B ${../ordinary-autotools-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${
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
    {
      name = "libtool.next-version-runtime";
      enabled = builtins.elem "libtool-next-version.in" final.additionalTemplates;
      tools = [ tools.python ];
      run = ''
        ${tools.python}/bin/python3 -B ${./next-version-runtime.py} "$out" \
          ${lib.escapeShellArg (lib.makeBinPath final.runtime.tools)}
      '';
    }
    (outputs.shebangs {
      paths = [
        "bin"
        "share/libtool/build-aux"
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
    (outputs.checkSymlinks {
      paths = [
        "lib/libltdl.so"
        "lib/libltdl.so.7"
      ];
    })
    (outputs.checkPaths {
      paths = elfPaths;
    })
  ];
  development = package: { aclocalDirectories = [ "${package}/share/aclocal" ]; };
  tvp.features = {
    toolDefaults = true;
    cxxDependencyTracking = true;
    acLibtool = true;
    ltdl = true;
    ltInit = true;
    nextVersion = builtins.elem "libtool-next-version.in" final.additionalTemplates;
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
