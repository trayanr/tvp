# Ordinary native 8.6.18 only: the 8.x Tcl extension ABI and full bundled Itcl/SQLite/TDBC/Thread installation are required by ordinary consumers.
# Earlier releases and source-bootstrap generations retain independent procedures.
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
  make = ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "tcl";
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
      python
    ];
    libraries = [
      zlib
      libgcc
    ];
  };
  runtime.libraries = [
    zlib
    libgcc
  ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit gzip findutils;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "tcl.prepare";
      bash = final.bash;
      inherit python;
      base = final.base;
      cwd = "source/unix";
    })
    (steps.shebangs {
      name = "tcl.package-shells";
      inherit python;
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
      ./configure --prefix="$out" --enable-threads --enable-shared --with-zlib=${zlib}
    '')
    (command "build" ''${make} binaries libraries doc'')
    (command "packages" ''
      export LD_LIBRARY_PATH="$PWD"
      ${make} packages TCLSH_NATIVE="$PWD/tclsh"
    '')
    (
      (command "check" ''
          export HOME="$TMPDIR" LOGNAME=builder TERM=xterm TZ=UTC
          export LD_LIBRARY_PATH="$PWD"
          ${coreutils}/bin/timeout 900 ${make} test-tcl TESTFLAGS='-verbose bpse' < /dev/zero 2>&1 | tee core-tests.log
          grep -Eq 'Total[[:space:]]+[1-9][0-9]*[[:space:]]+Passed[[:space:]]+[1-9][0-9]*' core-tests.log
        if grep -E 'Failed[[:space:]]+[1-9][0-9]*|Test file error:|Test files exiting with errors:' core-tests.log; then exit 1; fi
      '')
      // {
        enabled = doCheck;
      }
    )
    (
      (command "check-packages" ''
            export HOME="$TMPDIR" LOGNAME=builder TERM=xterm TZ=UTC
            export LD_LIBRARY_PATH="$PWD"
            "$CC" ${./client-probe.c} -ldl -o client-probe
        ${python}/bin/python3 -B ${./package-results.py} preflight "$PWD/.." client-preflight.json "$PWD/client-probe"
          ${coreutils}/bin/timeout 900 ${make} test-packages TCLSH_NATIVE="$PWD/tclsh" TESTFLAGS='-verbose bpse' 2>&1 | tee package-tests.log
            ${python}/bin/python3 -B ${./package-results.py} classify package-tests.log client-preflight.json package-results.json
      '')
      // {
        enabled = doCheck;
      }
    )
    (command "install" ''
      export LD_LIBRARY_PATH="$PWD"
      ${make} install install-private-headers TCLSH_NATIVE="$PWD/tclsh"
      mkdir -p "$out/nix-support"
      if test -f package-results.json; then cp package-results.json "$out/nix-support/bundled-upstream.json"; fi
      ln -s tclsh8.6 "$out/bin/tclsh"
      chmod -R u+w "$out"
    '')
    (command "receipt" ''
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (outputs.shebangs {
      inherit python;
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
      inherit python binutils;
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [ "runtime" ];
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
      elfKinds = [ "runtime" ];
    })
    (outputs.development {
      inherit python;
      libraries = [ zlib ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [ "runtime" ];
    })
  ];
  tvp.features = {
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
