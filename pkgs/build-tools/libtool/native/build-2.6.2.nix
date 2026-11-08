# Ordinary 2.6.2 only: explicit owned construction and installed macro interface.
# Shipped configure/Makefiles stay authoritative; no maintainer regeneration.
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
  make = ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
  elfPaths = [ "lib" ];
in
{
  pname = "libtool";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  environment = {
    tools = [
      autoconf
      automake
      m4
      file
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
    tools = [
      coreutils
      sed
      grep
      gawk
      bash
      autoconf
      automake
      m4
      file
    ];
    libraries = [ ];
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit xz findutils;
      compression = "xz";
    })
    (
      (command "libtool.patch" ''
        ${lib.concatMapStringsSep "\n" (p: "${patch}/bin/patch -p1 < ${p}") patches}
        # Preserve shipped timestamps so adapted templates cannot trigger aclocal,
        # automake or help2man regeneration. Only ltmain.sh is explicitly rebuilt.
        for script in libtoolize.in build-aux/ltmain.in; do
          cp -p "$script" "$script.timestamp"
          sed -i -e 's|@TVP_AUTOCONF@|${autoconf}/bin/autoconf|g' -e 's|@TVP_AUTOMAKE@|${automake}/bin/automake|g' "$script"
          touch -r "$script.timestamp" "$script"
          rm "$script.timestamp"
        done
        # Configure emits executable programs from non-executable templates.
        # Opt them into explicit interpreter preparation without changing mtime.
        chmod +x libtoolize.in libtool-next-version.in
      '')
      // {
        tools = [
          patch
          sed
        ];
      }
    )
    (steps.shebangs {
      name = "libtool.source-interpreter";
      inherit python;
      paths = [
        "libtoolize.in"
        "libtool-next-version.in"
      ];
      names = [ "sh" ];
      interpreter = "${final.bash}/bin/bash";
    })
    (steps.prepareAutotools {
      name = "libtool.prepare";
      bash = final.bash;
      inherit python;
      base = final.base;
    })
    (command "libtool.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" --enable-shared --enable-static M4=${m4}/bin/m4 FILECMD=${file}/bin/file ${lib.escapeShellArgs configureFlags}
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
    (outputs.shebangs {
      inherit python;
      paths = [
        "bin"
        "share/libtool/build-aux"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    {
      name = "libtool.runtime-tools";
      tools = [ python ];
      run = ''${python}/bin/python3 -B ${./runtime-tools.py} "$out" ${
        lib.escapeShellArg (builtins.toJSON (map (p: "${p}/bin") final.runtime.tools))
      }'';
    }
    (outputs.strip {
      inherit python binutils;
      paths = elfPaths;
    })
    (outputs.stripArchives {
      inherit python binutils;
      paths = [ "lib/libltdl.a" ];
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      paths = elfPaths;
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
    })
    # libltdl's shared/static interface, .la file and installed aliases are retained.
    (outputs.development {
      inherit python;
      libraries = [ ];
    })
    (outputs.checkSymlinks {
      inherit python;
      paths = [
        "lib/libltdl.so"
        "lib/libltdl.so.7"
      ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = elfPaths;
    })
  ];
  development = package: { aclocalDirectories = [ "${package}/share/aclocal" ]; };
  tvp.features = {
    cxxDependencyTracking = true;
    acLibtool = true;
    ltdl = true;
    ltInit = true;
  };
  meta = {
    description = "GNU portable library build tools and libltdl loader library";
    license = [
      lib.licenses.gpl2Plus
      lib.licenses.lgpl2Plus
    ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "libtool";
  };
}
