# M4 1.4.20 corrects attribute placement and uses the upstream compiler dialect.
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
  cStandard ? null,
  doCheck ? true,
  configureFlags ? [ ],
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
  pname = "m4";
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
    doCheck
    configureFlags
    ;
  inherit cStandard;
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
  };
  environment = {
    tools = [
      final.gnumake
      final.sed
      final.grep
      final.gawk
      final.diffutils
      final.findutils
    ];
    libraries = [ ];
    overrides.flags.NIX_CFLAGS_COMPILE = lib.optional (
      final.cStandard != null
    ) "-std=${final.cStandard}";
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
      name = "m4.prepare";
      bash = final.bash;
      python = final.python;
      base = final.base;
    })
    (steps.shebangs {
      name = "m4.check-shells";
      python = final.python;
      paths = [
        "checks"
        "tests"
        "build-aux"
      ];
      names = [ "sh" ];
      interpreter = "${final.bash}/bin/bash";
    })
    (command "m4.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" --with-syscmd-shell=${final.bash}/bin/bash ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "m4.shell-slot" ''
      ${final.python}/bin/python3 -B ${./shell-slot.py} lib/config.h
    '')
    (command "m4.build" ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'')
    (
      (command "m4.check" ''${final.python}/bin/python3 -B ${./check.py} ${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash check'')
      // {
        enabled = final.doCheck;
      }
    )
    (command "m4.install" ''
      ${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "m4.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "m4.relocate";
      tools = [ final.python ];
      run = ''
        ${final.python}/bin/python3 -B ${./relocate.py} "$out" "$TVP_ARTIFACT_ROOT" "${final.bash}/bin/bash" "${final.runtime.shell}/bin/bash" "${final.patchelf}/bin/patchelf"
      '';
    }
    {
      name = "output.manuals";
      tools = [ final.gzip ];
      run = ''
        ${final.gzip}/bin/gzip -n -9 "$out/share/man/man1/m4.1"
        rm -f "$out/share/info/dir"
      '';
    }
    (outputs.strip {
      python = final.python;
      binutils = final.binutils;
      paths = [ "bin/m4" ];
    })
    (outputs.rpaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [ "bin/m4" ];
    })
    (outputs.checkPaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      paths = [ "bin/m4" ];
    })
  ];
  meta = {
    description = "GNU macro processor";
    homepage = "https://www.gnu.org/software/m4/";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
    mainProgram = "m4";
  };
}
