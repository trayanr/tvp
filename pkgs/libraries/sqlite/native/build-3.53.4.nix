# Ordinary native 3.53.4: Fossil autosetup source and the complete --all profile,
# including the Tcl8 stub extension. Earlier releases and construction generations
# retain independent procedures; this native boundary serves 3.53.4 only.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  pkgConfig,
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
  tcl,
  readline,
  doCheck ? true,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "sqlite.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash TCLLIBDIR="$out/lib/tcl"'';
in
{
  pname = "sqlite";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  environment = {
    tools = [
      pkgConfig
      gnumake
      sed
      grep
      gawk
      diffutils
      findutils
      tcl
    ];
    libraries = [
      readline
      tcl
    ];
  };
  # The CLI embeds SQLite and links Readline; the Tcl module embeds SQLite and
  # uses Tcl stubs. Neither module nor libsqlite3 dynamically links target Tcl.
  runtime.libraries = [ readline ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit gzip findutils;
      compression = "gzip";
    })
    (steps.shebangs {
      name = "sqlite.source-shells";
      inherit python;
      paths = [
        "configure"
        "autosetup"
        "tool"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      export autosetup_tclsh=${tcl}/bin/tclsh
      export CC_FOR_BUILD="$CC"
      ./configure --prefix="$out" --all --enable-shared --enable-static \
        --enable-tcl --with-tcl=${tcl}/lib --with-tclsh=${tcl}/bin/tclsh \
        --enable-readline --with-readline-header=${readline}/include/readline/readline.h \
        --with-readline-ldflags="-L${readline}/lib -lreadline" --disable-zlib \
        TCLLIBDIR="$out/lib/tcl"
      grep -Fx 'HAVE_TCL = 1' Makefile
      grep -Fx 'TCL_CONFIG_SH = ${tcl}/lib/tclConfig.sh' Makefile
      grep -Fx 'TCLSH_CMD = ${tcl}/bin/tclsh' Makefile
      grep -Fx 'B.tclsh = $(TCLSH_CMD)' Makefile
      grep -Fx 'TCL_MAJOR_VERSION = 8' Makefile
    '')
    (command "build" ''${make} all'')
    (
      (command "check" ''
        export HOME="$TMPDIR" TERM=xterm TZ=UTC
        ${make} testfixture
        # Invoke the just-built fixture, never the Tcl runner's bundled SQLite.
        ./testfixture <<'TCL'
        if {[sqlite3 -version] ne "${version}"} {error "wrong testfixture SQLite"}
        puts "testfixture SQLite [sqlite3 -version]"
        TCL
        ${coreutils}/bin/timeout 900 ./testfixture test/veryquick.test 2>&1 | tee upstream.log
        grep -E '[1-9][0-9]* tests? executed|[1-9][0-9]* tests? run|[1-9][0-9]* errors out of [1-9][0-9]* tests' upstream.log
        grep -E '^0 errors out of [1-9][0-9]* tests' upstream.log
      '')
      // {
        enabled = doCheck;
      }
    )
    (command "install" ''
      ${make} install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
      # Man pages are the only compressed output in the retained profile.
      ${gzip}/bin/gzip -n "$out/share/man/man1/sqlite3.1"
      test -f "$out/lib/libsqlite3.a"
      test -f "$out/lib/tcl/libsqlite${version}.so"
      test -f "$out/lib/tcl/pkgIndex.tcl"
    '')
    (outputs.strip {
      inherit python binutils;
      paths = [
        "bin"
        "lib"
      ];
    })
    (outputs.stripArchives {
      inherit python binutils;
      paths = [ "lib" ];
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [
        "bin"
        "lib"
      ];
    })
    (outputs.development {
      inherit python;
      libraries = [ ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = [
        "bin"
        "lib"
      ];
    })
  ];
  tvp = {
    reportedVersion = version;
    pkgConfigVersion = version;
    features = {
      pkgConfig = true;
      prepareV2 = true;
      libVersionFunction = true;
    };
  };
  meta = {
    description = "Self-contained SQL database engine";
    homepage = "https://sqlite.org/";
    license = lib.licenses.publicDomain;
    platforms = [ "x86_64-linux" ];
  };
}
