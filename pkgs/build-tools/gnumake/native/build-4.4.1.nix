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
  # Equal-width compiled-prefix ABI; the artifact remains a distinct producer.
  artifactName = "${final.pname}-${final.version}";
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
      sed
      grep
      gawk
      diffutils
      findutils
      perl
    ];
    libraries = [ ];
  };
  runtime = {
    libraries = final.environment.libraries or [ ];
    shell = bash;
  };
  upstreamPreparation = [
    {
      name = "gnumake.check-shell";
      cwd = "source";
      tools = [ python ];
      run = ''${python}/bin/python3 -B ${./prepare-check.py} "${final.bash}/bin/sh"'';
    }
  ];
  upstreamCheck = {
    enabled = doCheck;
    before = "gnumake.install";
    command = (
      (command "gnumake.check" ''
        status=0
        ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash check > upstream.log 2>&1 || status=$?
        cat upstream.log
        ${python}/bin/python3 -B ${./check-upstream.py} "$status"
      '')
      // {
        enabled = doCheck;
      }
    );
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      inherit gzip findutils;
      tar = gnutar;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "gnumake.autotools";
      bash = final.bash;
      inherit python;
      base = final.base;
    })
    {
      name = "gnumake.prepare";
      cwd = "source";
      tools = [ python ];
      run = ''
        ${python}/bin/python3 -B ${./prepare.py} ${lib.escapeShellArg "${final.bash}/bin/sh"}
      '';
    }
    (command "gnumake.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      ${final.bash}/bin/bash ./configure --prefix="$out" --disable-dependency-tracking \
        PERL=${perl}/bin/perl ${lib.escapeShellArgs configureFlags}
    '')
    (command "gnumake.build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'')
    (command "gnumake.install" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "gnumake.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "gnumake.relocate";
      tools = [ python ];
      run = ''${python}/bin/python3 -B ${../../owned-split-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        lib.escapeShellArg (
          builtins.toJSON {
            slots = [
              [
                "${final.bash}/bin/sh"
                "${final.runtime.shell}/bin/sh"
              ]
            ];
          }
        )
      } ${../../../../lib/installed-tree.py}'';
    }
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
