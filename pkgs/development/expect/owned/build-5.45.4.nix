# Native Expect extension and real PTY interpreter, using installed Tcl 8.6.
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
  tcl,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "expect.${name}";
      cwd = "source";
      run = ''
        export TVP_SOURCE_ROOT
        mkdir -p "$evidence"
        status=0
        ${bash}/bin/bash -euc ${lib.escapeShellArg run} > "$evidence/expect.${name}.log" 2>&1 || status=$?
        printf '%s\n' "$status" > "$evidence/expect.${name}.status"
        ${
          if name == "check" then
            ''cat "$evidence/expect.${name}.log"''
          else
            ''if (( status )); then cat "$evidence/expect.${name}.log"; exit "$status"; fi''
        }
      '';
    };
in
{
  pname = "expect";
  version = "5.45.4";
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
    tools = buildTools ++ [ tcl ];
    libraries = [ tcl ];
    overrides.values.CFLAGS = "-O2 -std=gnu89";
  };
  runtime.libraries = [ tcl ];
  buildEnvironment =
    { tool, ... }:
    {
      paths.TCLLIBPATH = {
        separator = " ";
        entries = [ "${tool}/lib/expect5.45.4" ];
      };
    };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit gzip findutils;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "expect.prepare";
      inherit bash python;
      base = final.base;
    })
    (command "configure" ''
      export CONFIG_SHELL=${bash}/bin/bash SHELL=${bash}/bin/bash
      sed -i 's|/bin/stty|${coreutils}/bin/stty|g' configure
      sed -i 's|$(TCLSH) $(srcdir)/fixline1|${tcl}/bin/tclsh $(srcdir)/fixline1|' Makefile.in
      # Original configure probes and K&R definitions predate C99. GCC 16's
      # default rejects them and misdetects every termios backend (pty_.c).
      # Keep the selected release's C dialect; do not affect any C++ consumer.
      ./configure --prefix="$out" --exec-prefix="$out" --libdir="$out/lib" --bindir="$out/bin" --with-tcl=${tcl}/lib --with-tclinclude=${tcl}/include --enable-shared --enable-threads
    '')
    (command "build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
    (command "check" ''
      export HOME="$TMPDIR" LOGNAME=builder TERM=xterm
      ${coreutils}/bin/timeout 300 ${gnumake}/bin/make test < /dev/zero
    '')
    (command "install" ''
      ${gnumake}/bin/make install
      chmod -R u+w "$out"
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (outputs.shebangs {
      inherit python;
      names = [
        "sh"
        "bash"
      ];
      paths = [ "bin" ];
      selfInterpreter = "bin/expect";
    })
    (outputs.strip {
      inherit python binutils;
      paths = [
        "bin"
        "lib"
      ];
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
      libraries = [ tcl ];
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
