# Make 4.3 uses its original shell-diagnostic harness and g++ built-in discovery.
# Complete ordinary procedure; latest and frozen construction remain independently selected.
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
  findutils,
  sed,
  grep,
  gawk,
  diffutils,
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
  # The selected compiler wrapper is an explicit tool interface. Keep required
  # transitive development paths when callers replace upstream scalar flags or
  # the structured flag defaults; no ambient NIX_* values participate.
  requiredEnvironment = final.base.environment {
    libraries = final.environment.libraries or [ ];
  };
  customCompile =
    environment.env ? CFLAGS
    || environment.env ? CXXFLAGS
    || environment.env ? CPPFLAGS
    || (final.environment.overrides.flags or { }) ? NIX_CFLAGS_COMPILE;
  customLink = environment.env ? LDFLAGS || (final.environment.overrides.flags or { }) ? NIX_LDFLAGS;
  compileFlags = environment.environmentContributions.NIX_CFLAGS_COMPILE.value;
  linkFlags = environment.environmentContributions.NIX_LDFLAGS.value;
  command =
    name: run:
    environment
    // {
      inherit name run;
      cwd = "source";
      env = environment.env // {
        NIX_CFLAGS_COMPILE =
          if customCompile then
            lib.concatStringsSep " " requiredEnvironment.environmentContributions.NIX_CFLAGS_COMPILE.value
          else
            "";
        NIX_LDFLAGS =
          if customLink then
            lib.concatStringsSep " " requiredEnvironment.environmentContributions.NIX_LDFLAGS.value
          else
            "";
        # Preserve Autoconf defaults; caller structured flags follow and can replace them.
        CFLAGS =
          environment.env.CFLAGS or (lib.concatStringsSep " " (
            [
              "-g"
              "-O2"
            ]
            ++ compileFlags
          ));
        CXXFLAGS =
          environment.env.CXXFLAGS or (lib.concatStringsSep " " (
            [
              "-g"
              "-O2"
            ]
            ++ compileFlags
          ));
        LDFLAGS = environment.env.LDFLAGS or (lib.concatMapStringsSep " " (f: "-Wl,${f}") linkFlags);
      };
    };
in
{
  pname = "gnumake";
  defaultCxx = "g++";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  inherit
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
    perl
    doCheck
    configureFlags
    stripFlags
    ;
  dependencyProviders = {
    bash = final.bash;
    coreutils = final.coreutils;
    gnumake = final.gnumake;
    gnutar = final.gnutar;
    gzip = final.gzip;
    findutils = final.findutils;
    sed = final.sed;
    grep = final.grep;
    gawk = final.gawk;
    diffutils = final.diffutils;
    python = final.python;
    binutils = final.binutils;
    patchelf = final.patchelf;
    perl = final.perl;
  };
  environment = {
    # Configure publishes CXX as Make's built-in command. Preserve PATH discovery
    # rather than retaining this build's compiler wrapper as a runtime tool.
    overrides.values.CXX = "c++";
    tools = [
      final.gnumake
      final.sed
      final.grep
      final.gawk
      final.diffutils
      final.findutils
      final.perl
    ];
    libraries = [ ];
  };
  runtime = {
    libraries = final.environment.libraries or [ ];
    shell = final.bash;
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      gzip = final.gzip;
      findutils = final.findutils;
      tar = final.gnutar;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "gnumake.autotools";
      bash = final.bash;
      python = final.python;
      base = final.base;
    })
    {
      name = "gnumake.prepare";
      cwd = "source";
      tools = [ final.python ];
      run = ''
        ${final.python}/bin/python3 -B ${./prepare-4.3.py} ${lib.escapeShellArg "${final.bash}/bin/sh"}
      '';
    }
    (command "gnumake.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      ${final.bash}/bin/bash ./configure --prefix="$out" --disable-dependency-tracking \
        PERL=${final.perl}/bin/perl ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "gnumake.build" ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'')
    (
      (command "gnumake.check" ''
        status=0
        ${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash check > upstream.log 2>&1 || status=$?
        cat upstream.log
        ${final.python}/bin/python3 -B ${./check-upstream-4.3.py} "$status"
      '')
      // {
        enabled = final.doCheck;
      }
    )
    (command "gnumake.install" ''
      ${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "gnumake.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "gnumake.relocate";
      tools = [ final.python ];
      run = ''
        ${final.python}/bin/python3 -B ${./relocate.py} "$out" "$TVP_ARTIFACT_ROOT" "${final.bash}/bin/sh" "${final.runtime.shell}/bin/sh" "${final.patchelf}/bin/patchelf"
      '';
    }
    {
      name = "output.manuals";
      tools = [ final.gzip ];
      run = ''
        ${final.gzip}/bin/gzip -n -9 "$out/share/man/man1/make.1"
        rm -f "$out/share/info/dir"
      '';
    }
    (outputs.strip {
      python = final.python;
      binutils = final.binutils;
      paths = [ "bin/make" ];
      flags = final.stripFlags;
    })
    (outputs.rpaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      base = final.base;
      paths = [ "bin/make" ];
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
    })
    (outputs.checkPaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      paths = [ "bin/make" ];
    })
  ];
  meta = {
    description = "GNU Make build tool";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
    mainProgram = "make";
  };
}
