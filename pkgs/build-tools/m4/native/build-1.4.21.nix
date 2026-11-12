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
    tools = [
      gnumake
      sed
      grep
      gawk
      diffutils
      findutils
    ];
    libraries = [ ];
  };
  runtime = {
    libraries = final.environment.libraries or [ ];
    shell = bash;
  };
  upstreamPreparation = [
    (steps.shebangs {
      name = "m4.check-shells";
      inherit python;
      paths = [
        "checks"
        "tests"
      ];
      names = [ "sh" ];
      interpreter = "${final.bash}/bin/bash";
    })
  ];
  upstreamCheck = {
    enabled = doCheck;
    before = "m4.install";
    command = (
      (command "m4.check" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash check'')
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
      name = "m4.prepare";
      bash = final.bash;
      inherit python;
      base = final.base;
    })
    (steps.shebangs {
      name = "m4.check-shells";
      inherit python;
      paths = [ "build-aux" ];
      names = [ "sh" ];
      interpreter = "${final.bash}/bin/bash";
    })
    (command "m4.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" --with-syscmd-shell=${final.bash}/bin/bash ${lib.escapeShellArgs configureFlags}
    '')
    (command "m4.shell-slot" "${python}/bin/python3 -B ${../ordinary/shell-slot.py} lib/config.h")
    (command "m4.build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'')
    (command "m4.install" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "m4.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "m4.relocate";
      tools = [ python ];
      run = ''${python}/bin/python3 -B ${../../owned-split-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        lib.escapeShellArg (
          builtins.toJSON {
            slots = [
              [
                "${final.bash}/bin/bash"
                "${final.runtime.shell}/bin/bash"
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
        ${gzip}/bin/gzip -n -9 "$out/share/man/man1/m4.1"
        rm -f "$out/share/info/dir"
      '';
    }
    (outputs.strip {
      inherit python binutils;
      paths = [ "bin/m4" ];
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      paths = [ "bin/m4" ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = [ "bin/m4" ];
    })
  ];
  meta = {
    description = "GNU macro processor";
    homepage = "https://www.gnu.org/software/m4/";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "m4";
  };
}
