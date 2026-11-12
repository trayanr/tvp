# Complete ordinary procedure for libtool 2.4.7; installed output repair follows the artifact split.
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
  m4,
  file,
  patch,
  gnumake,
  gnutar,
  xz,
  findutils,
  sed,
  grep,
  gawk,
  diffutils,
  python,
  binutils,
  patchelf,
  patches ? [ ],
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
  pname = "libtool";
  inherit
    base
    src
    version
    bash
    coreutils
    autoconf
    automake
    m4
    file
    patch
    gnumake
    gnutar
    xz
    findutils
    sed
    grep
    gawk
    diffutils
    python
    binutils
    patchelf
    configureFlags
    patches
    ;
  dependencyProviders = {
    bash = final.bash;
    coreutils = final.coreutils;
    autoconf = final.autoconf;
    automake = final.automake;
    m4 = final.m4;
    file = final.file;
    patch = final.patch;
    gnumake = final.gnumake;
    gnutar = final.gnutar;
    xz = final.xz;
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
      xz = final.xz;
      findutils = final.findutils;
      compression = "xz";
    })
    (
      (command "libtool.patch" ''
        ${lib.concatMapStringsSep "\n" (p: "${final.patch}/bin/patch -p1 < ${p}") final.patches}
        # Preserve shipped timestamps so adapted templates cannot trigger aclocal,
        # automake or help2man regeneration. Only ltmain.sh is explicitly rebuilt.
        for script in libtoolize.in build-aux/ltmain.in; do
          test "$(${final.grep}/bin/grep -Fo '@TVP_AUTOCONF@' "$script" | ${final.coreutils}/bin/wc -l)" = 1
          test "$(${final.grep}/bin/grep -Fo '@TVP_AUTOMAKE@' "$script" | ${final.coreutils}/bin/wc -l)" = 1
          cp -p "$script" "$script.timestamp"
          sed -i -e 's|@TVP_AUTOCONF@|${final.autoconf}/bin/autoconf|g' -e 's|@TVP_AUTOMAKE@|${final.automake}/bin/automake|g' "$script"
          touch -r "$script.timestamp" "$script"
          rm "$script.timestamp"
        done
        # Configure emits executable programs from non-executable templates.
        # Opt them into explicit interpreter preparation without changing mtime.
        chmod +x libtoolize.in libtool-next-version.in
      '')
      // {
        tools = [
          final.patch
          final.sed
        ];
      }
    )
    (steps.shebangs {
      name = "libtool.source-interpreter";
      python = final.python;
      paths = [
        "libtoolize.in"
        "libtool-next-version.in"
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
    (steps.split "libtool.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "libtool.relocate-runtime";
      tools = [ final.python ];
      run = ''${final.python}/bin/python3 -B ${../../ordinary-autotools-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${
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
        "share/libtool/build-aux"
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
    (outputs.checkSymlinks {
      python = final.python;
      paths = [
        "lib/libltdl.so"
        "lib/libltdl.so.7"
      ];
    })
    (outputs.checkPaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
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
