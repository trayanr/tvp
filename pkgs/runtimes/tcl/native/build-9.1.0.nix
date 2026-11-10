# Native Tcl 9.1.0 only: the Tcl 9 stub ABI and Thread 3 bundle require a
# distinct procedure. Zipfs script-image installation remains explicitly disabled.
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
  zlib,
  libgcc,
  patch,
  patches,
  doCheck ? true,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "tcl.${name}";
      cwd = "source/unix";
      inherit run;
    };
  make = ''${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "tcl";
  inherit
    base
    src
    version
    bash
    coreutils
    patches
    ;
  tools = {
    inherit
      pkgConfig
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
      patch
      ;
  };
  libraries = {
    inherit zlib libgcc;
  };
  environment = {
    tools = [
      final.tools.pkgConfig
      final.tools.gnumake
      final.tools.sed
      final.tools.grep
      final.tools.gawk
      final.tools.diffutils
      final.tools.findutils
      final.tools.python
    ];
    libraries = [
      final.libraries.zlib
      final.libraries.libgcc
    ];
  };
  runtime = {
    inherit (final.libraries) zlib libgcc;
    libraries = [
      final.runtime.zlib
      final.runtime.libgcc
    ];
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.tools.gnutar;
      inherit (final.tools) gzip findutils;
      compression = "gzip";
    })
    {
      name = "tcl.patch";
      cwd = "source";
      tools = [ final.tools.patch ];
      run = lib.concatMapStringsSep "\n" (
        p: "${final.tools.patch}/bin/patch --batch --fuzz=0 -p1 < ${p}"
      ) final.patches;
    }
    (steps.prepareAutotools {
      name = "tcl.prepare";
      bash = final.bash;
      inherit (final.tools) python;
      base = final.base;
      cwd = "source/unix";
    })
    (steps.shebangs {
      name = "tcl.package-shells";
      inherit (final.tools) python;
      paths = [
        "pkgs"
        "unix"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      export LDFLAGS="''${LDFLAGS:-} -Wl,--no-as-needed -lgcc_s -Wl,--as-needed"
      ./configure --prefix="$out" --enable-threads --enable-shared --disable-zipfs --with-zlib=${final.libraries.zlib}
    '')
    (command "build" ''${make} binaries libraries doc'')
    (command "packages" ''
      export LD_LIBRARY_PATH="$PWD"
      ${make} packages TCLSH_NATIVE="$PWD/tclsh"
    '')
    (
      (command "check" ''
          export HOME="$TMPDIR" LOGNAME=builder TERM=xterm TZ=UTC LANG=C.UTF-8 LC_ALL=C.UTF-8
        export TVP_TEST_SHELL=${final.bash}/bin/bash TVP_TEST_ENV=${final.coreutils}/bin/env
          export LD_LIBRARY_PATH="$PWD"
          ${final.coreutils}/bin/timeout 900 ${make} test-tcl TESTFLAGS='-verbose bpse' < /dev/zero 2>&1 | tee core-tests.log
          grep -Eq 'Total[[:space:]]+[1-9][0-9]*[[:space:]]+Passed[[:space:]]+[1-9][0-9]*' core-tests.log
        if grep -E 'Failed[[:space:]]+[1-9][0-9]*|Test file error:|Test files exiting with errors:' core-tests.log; then exit 1; fi
      '')
      // {
        enabled = final.tvp.features.doCheck;
      }
    )
    (
      (command "check-packages" ''
            export HOME="$TMPDIR" LOGNAME=builder TERM=xterm TZ=UTC LANG=C.UTF-8 LC_ALL=C.UTF-8
        export TVP_TEST_SHELL=${final.bash}/bin/bash TVP_TEST_ENV=${final.coreutils}/bin/env
            export LD_LIBRARY_PATH="$PWD"
            "$CC" ${./client-probe.c} -ldl -o client-probe
        ${final.tools.python}/bin/python3 -B ${./package-results-9.1.py} preflight "$PWD/.." client-preflight.json "$PWD/client-probe"
          ${final.coreutils}/bin/timeout 900 ${make} test-packages TCLSH_NATIVE="$PWD/tclsh" TESTFLAGS='-verbose bpse' 2>&1 | tee package-tests.log
            ${final.tools.python}/bin/python3 -B ${./package-results-9.1.py} classify package-tests.log client-preflight.json package-results.json
      '')
      // {
        enabled = final.tvp.features.doCheck;
      }
    )
    (command "install" ''
      export LD_LIBRARY_PATH="$PWD"
      ${make} install install-private-headers TCLSH_NATIVE="$PWD/tclsh"
      mkdir -p "$out/nix-support"
      if test -f package-results.json; then cp package-results.json "$out/nix-support/bundled-upstream.json"; fi
      ln -s tclsh9.1 "$out/bin/tclsh"
      chmod -R u+w "$out"
    '')
    (command "receipt" ''
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (outputs.shebangs {
      inherit (final.tools) python;
      paths = [
        "bin"
        "lib"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (outputs.strip {
      inherit (final.tools) python binutils;
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [ "runtime" ];
    })
    (outputs.stripArchives {
      inherit (final.tools) python binutils;
      paths = [ "lib" ];
    })
    (outputs.rpaths {
      inherit (final.tools) python binutils patchelf;
      base = final.base;
      libraries =
        assert
          map toString final.runtime.libraries == map toString [
            final.runtime.zlib
            final.runtime.libgcc
          ]
          || throw "Tcl runtime.libraries is derived; edit runtime.zlib or libgcc instead.";
        final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [ "runtime" ];
    })
    (outputs.development {
      inherit (final.tools) python;
      libraries = [ final.libraries.zlib ];
    })
    (outputs.checkPaths {
      inherit (final.tools) python binutils patchelf;
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [ "runtime" ];
    })
  ];
  tvp.features = {
    inherit doCheck;
    are = true;
    pkgConfig = true;
    zipfsImage = false;
    bundledPackages = true;
    threads = true;
  };
  meta = {
    description = "Tool Command Language interpreter";
    homepage = "https://www.tcl-lang.org/";
    license = lib.licenses.tcltk;
    platforms = [ "x86_64-linux" ];
  };
}
