# Tcl 8.6 is deliberately selected for Expect's public Tcl API.
{
  tvp,
  lib,
  base,
  src,
  bash,
  coreutils,
  buildTools,
  gnumake,
  gnutar,
  gzip,
  findutils,
  python,
  binutils,
  patchelf,
  zlib,
  libgcc,
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
      run = ''
        export TVP_SOURCE_ROOT
        mkdir -p "$evidence"
        status=0
        ${bash}/bin/bash -euc ${lib.escapeShellArg run} > "$evidence/tcl.${name}.log" 2>&1 || status=$?
        printf '%s\n' "$status" > "$evidence/tcl.${name}.status"
        ${
          if name == "check" then
            ''cat "$evidence/tcl.${name}.log"''
          else
            ''if (( status )); then cat "$evidence/tcl.${name}.log"; exit "$status"; fi''
        }
      '';
    };
in
{
  pname = "tcl";
  version = "8.6.18";
  inherit
    base
    src
    bash
    coreutils
    ;
  outputs = [
    "out"
    "evidence"
  ];
  environment = {
    tools = buildTools;
    libraries = [
      zlib
      libgcc
    ];
  };
  # pthread_exit/cancellation dlopens libgcc_s even though Tcl is C. Retain an
  # explicit native-generation dependency rather than libc's default search.
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
      inherit bash python;
      base = final.base;
      cwd = "source/unix";
    })
    (command "configure" ''
      export CONFIG_SHELL=${bash}/bin/bash SHELL=${bash}/bin/bash
      export LDFLAGS="''${LDFLAGS:-} -Wl,--no-as-needed -lgcc_s -Wl,--as-needed"
      ./configure --prefix="$out" --enable-threads --enable-shared
      grep '^ZLIB_INCLUDE[[:space:]]*=[[:space:]]*$' Makefile
    '')
    (command "build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" binaries libraries doc'')
    (command "check" ''
      export HOME="$TMPDIR" LOGNAME=builder TERM=xterm TZ=UTC
      ${coreutils}/bin/timeout 900 ${gnumake}/bin/make test-tcl TESTFLAGS='-verbose bpse' < /dev/zero
    '')
    (command "install" ''
      ${gnumake}/bin/make install-binaries install-libraries install-doc install-headers install-private-headers install-msgs install-tzdata
      ln -s tclsh8.6 "$out/bin/tclsh"
      chmod -R u+w "$out"
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
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
      paths = [
        "bin"
        "lib"
      ];
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
    })
  ];
  meta.platforms = [ "x86_64-linux" ];
}
