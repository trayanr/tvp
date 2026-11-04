# Native Make embeds its default shell, so installation stays in one stage.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  gnumake,
  gnutar,
  gzip,
  python,
  binutils,
  patchelf,
  perl,
  doCheck ? true,
  configureFlags ? [ ],
  stripFlags ? [
    "-S"
    "-p"
  ],
}:
let
  inherit (tvp.builder) steps outputs;
in
final:
let
  environment = final.base.environment final.environment;
  command =
    name: run:
    environment
    // {
      inherit name run;
      cwd = "source";
    };
in
{
  pname = "gnumake";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  environment = {
    # Configure publishes CXX as Make's built-in command. Preserve PATH discovery
    # rather than retaining this build's compiler wrapper as a runtime tool.
    overrides.values.CXX = "c++";
    tools = [
      gnumake
      perl
    ];
    libraries = [ ];
  };
  runtime = {
    libraries = [ ];
    shell = bash;
  };
  plan = steps.sequence [
    (steps.unpack {
      inherit src gzip;
      tar = gnutar;
      compression = "gzip";
    })
    {
      name = "gnumake.prepare";
      cwd = "source";
      tools = [ python ];
      run = ''
        ${python}/bin/python3 -B ${./prepare.py} ${lib.escapeShellArg "${final.runtime.shell}/bin/sh"}
      '';
    }
    (command "gnumake.configure" ''
      export CONFIG_SHELL=${bash}/bin/bash
      ${bash}/bin/bash ./configure --prefix="$out" --disable-dependency-tracking \
        PERL=${perl}/bin/perl ${lib.escapeShellArgs configureFlags}
    '')
    (command "gnumake.build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash'')
    (
      (command "gnumake.check" ''
        status=0
        ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash check > upstream.log 2>&1 || status=$?
        cat upstream.log
        ${python}/bin/python3 -B ${./check-upstream.py} "$status"
      '')
      // {
        enabled = doCheck;
      }
    )
    (command "gnumake.install" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash install
    '')
    {
      name = "output.manuals";
      tools = [ gzip ];
      run = ''
        ${gzip}/bin/gzip -n -9 "$out/share/man/man1/make.1"
        rm -f "$out/share/info/dir"
      '';
    }
    (outputs.strip {
      inherit python binutils;
      paths = [ "bin/make" ];
      flags = stripFlags;
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      paths = [ "bin/make" ];
      libraries = final.runtime.libraries;
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = [ "bin/make" ];
    })
  ];
  meta = {
    description = "GNU Make build tool";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "make";
  };
}
