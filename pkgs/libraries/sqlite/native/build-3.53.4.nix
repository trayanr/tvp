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
  testZlib,
  doCheck ? true,
}@args:
final:
let
  inherit (final)
    base
    src
    version
    bash
    coreutils
    ;
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "sqlite.${name}";
      cwd = "source";
      # Link-time resolution for dependencies of the declared shared providers.
      # These search-only flags expose neither zlib headers nor -lz to configure.
      env = (final.base.environment final.environment).env // {
        NIX_LDFLAGS =
          (final.base.environment final.environment).env.NIX_LDFLAGS
          + " -rpath-link ${readline.tvp.deps.ncurses}/lib -rpath-link ${tcl.tvp.deps.zlib}/lib";
      };
      inherit run;
    };
  make = ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash TCLLIBDIR="$out/lib/tcl"'';
in
{
  pname = "sqlite";
  inherit (args)
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
    ];
  };
  # The CLI embeds SQLite and links Readline; the Tcl module embeds SQLite and
  # uses Tcl stubs. Neither module nor libsqlite3 dynamically links target Tcl.
  runtime.libraries = [ readline ];
  artifactPlan = steps.sequence [
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
        --with-readline-ldflags="-L${readline}/lib -lreadline" \
        TCLLIBDIR="$out/lib/tcl"
      grep -E '^LDFLAGS.zlib = *$' Makefile
      grep -Fx 'HAVE_TCL = 1' Makefile
      grep -Fx 'TCL_CONFIG_SH = ${tcl}/lib/tclConfig.sh' Makefile
      grep -Fx 'TCLSH_CMD = ${tcl}/bin/tclsh' Makefile
      grep -Fx 'B.tclsh = $(TCLSH_CMD)' Makefile
      grep -Fx 'TCL_MAJOR_VERSION = 8' Makefile
    '')
    (command "build" ''${make} all'')
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
  ];
  finalizeHelper = ./../ordinary/finalize.py;
  inherit doCheck;
  upstreamPlan = steps.sequence [
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
        --with-readline-ldflags="-L${readline}/lib -lreadline" \
        TCLLIBDIR="$out/lib/tcl"
      grep -E '^LDFLAGS.zlib = *$' Makefile
      grep -Fx 'HAVE_TCL = 1' Makefile
      grep -Fx 'TCL_CONFIG_SH = ${tcl}/lib/tclConfig.sh' Makefile
      grep -Fx 'TCLSH_CMD = ${tcl}/bin/tclsh' Makefile
      grep -Fx 'B.tclsh = $(TCLSH_CMD)' Makefile
      grep -Fx 'TCL_MAJOR_VERSION = 8' Makefile
    '')
    (command "build" ''${make} all'')
  ];
  upstreamCheck = (
    (command "check" ''
      export HOME="$TMPDIR" TERM=xterm TZ=UTC
      # zipfile.c is unconditional in the upstream testfixture. These inputs
      # apply only to the fixture, preserving the installed no-zlib profile.
      export NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE -isystem ${testZlib}/include -DSQLITE_HAVE_ZLIB=1"
      export NIX_LDFLAGS="$NIX_LDFLAGS -L${testZlib}/lib -rpath ${testZlib}/lib -rpath ${tcl}/lib"
      ${make} testfixture LDFLAGS.libsqlite3="-lm -lz"
      # A script file gives errors a nonzero exit, unlike interactive stdin.
      cat > fixture-version.tcl <<'TCL'
      if {[sqlite3 -version] ne "${version}"} {error "wrong testfixture SQLite"}
      puts "testfixture SQLite [sqlite3 -version]"
      TCL
      ./testfixture fixture-version.tcl
      # The supported runner isolates each veryquick file in a fixture process.
      # Direct veryquick.test leaks a prior file's Tcl logging callback into
      # sessionnoact; retain every case with upstream's process isolation.
      cat > fixture-runner.tcl <<'TCL'
      if {[package require -exact sqlite3 ${version}] ne "${version}"} {error "wrong runner SQLite"}
      set argv0 test/testrunner.tcl
      set argv [list --jobs 8 veryquick]
      source $argv0
      sqlite3 results testrunner.db
      set jobs [results onecolumn {select count(*) from jobs}]
      set cases [results onecolumn {select sum(ntest) from jobs}]
      set errors [results onecolumn {select sum(nerr) from jobs}]
      set unfinished [results onecolumn {select count(*) from jobs where state!='done'}]
      puts "upstream veryquick jobs=$jobs cases=$cases errors=$errors unfinished=$unfinished"
      if {$jobs<1 || $cases<1 || $errors!=0 || $unfinished!=0} {exit 1}
      TCL
      ${coreutils}/bin/timeout 900 ./testfixture fixture-runner.tcl 2>&1 | tee upstream.log
      cat testrunner.log
      grep -E '^upstream veryquick jobs=[1-9][0-9]* cases=[1-9][0-9]* errors=0 unfinished=0$' upstream.log
    '')
    // {
      enabled = final.doCheck;
    }
  );
  plan = steps.sequence (
    final.artifactPlan
    ++ [
      (steps.split "sqlite.finalize")
      (outputs.copyArtifacts { coreutils = final.coreutils; })
      {
        name = "sqlite.relocate";
        tools = [ python ];
        run = ''${python}/bin/python3 -B ${final.finalizeHelper} "$out" "$TVP_ARTIFACT_ROOT"'';
      }
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
    ]
  );
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
