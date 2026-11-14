# Complete GNU Make production procedure. Test-harness eras are independent U inputs.
{
  tvp,
  lib,
  base,
  src,
  version,
  defaultCxx ? "c++",
  doCheck ? true,
  configureFlags ? [ ],
  stripFlags ? [
    "-S"
    "-p"
  ],
  upstreamProfile ? "4.4.1",
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  environment = final.base.environment final.environment;
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
  # Preserve the existing scalar/structured flag contract and required transitive
  # development flags. Autoconf defaults remain before caller-provided flag lists.
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
  checkpoint = "nix-support/gnumake-build-tree";
in
{
  pname = "gnumake";
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    defaultCxx
    doCheck
    configureFlags
    stripFlags
    upstreamProfile
    ;
  inherit (tools) bash coreutils;
  installedInterface.defaultCxx = final.defaultCxx;
  environment = {
    # Keep the existing configure-time choice. Upstream 4.3/4.4 still publish
    # g++ as their built-in command; 4.4.1 publishes c++ (checked by the suite).
    overrides.values.CXX = "c++";
    tools = [
      tools.gnumake
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
    ];
    libraries = [ ];
  };
  runtime = {
    libraries = final.environment.libraries or [ ];
    shell = final.bash;
    dlopenDirectories = [ ];
  };
  productionPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (steps.prepareAutotools { name = "gnumake.autotools"; })
    {
      name = "gnumake.prepare";
      cwd = "source";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${./prepare.py} ${lib.escapeShellArg "${tools.bash}/bin/sh"}'';
    }
    (command "gnumake.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash
      # configure.ac declares Perl as a test-only program. Bind the command name
      # without a production provider; U supplies/checks its declared Perl below.
      ${tools.bash}/bin/bash ./configure --prefix="$out" --disable-dependency-tracking \
        PERL=perl ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "gnumake.build" ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'')
    (command "gnumake.install" ''
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (
      (command "gnumake.save-build-tree" ''
        ${tools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/${checkpoint}"
      '')
      // {
        tools = environment.tools ++ [ tools.python ];
      }
    )
  ];
  upstreamPreparation = [
    {
      name = "gnumake.prepare-tests";
      tools = [ tools.python ];
      run = ''
        ${tools.python}/bin/python3 -B ${./tests/upstream/prepare.py} \
          ${lib.escapeShellArg final.upstreamProfile} ${lib.escapeShellArg "${tools.bash}/bin/sh"}
      '';
    }
  ];
  upstreamPlan =
    artifact:
    [
      {
        name = "gnumake.restore-build-tree";
        tools = [ tools.python ];
        run = ''${tools.python}/bin/python3 -B ${./tests/restore.py} ${artifact}/${checkpoint} "$TVP_SOURCE_ROOT"'';
      }
    ]
    ++ map (
      step:
      step
      // {
        run = ''
          cd "$(cat "$TVP_SOURCE_ROOT/tree-path")"
          ${step.run}
        '';
      }
    ) final.upstreamPreparation;
  upstreamCheck =
    (command "gnumake.check" ''
      test -n "$MAKE_TEST_PERL"
      test -x "$MAKE_TEST_PERL"
      status=0
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash \
        PERL="$MAKE_TEST_PERL" check > upstream.log 2>&1 || status=$?
      cat upstream.log
      # Retain every classifier input; avoid storing unrelated test fixtures or
      # special files left by upstream's shell/filesystem cases.
      mkdir -p "$out/raw/work"
      cp upstream.log "$out/raw/upstream.log"
      test -d tests/work
      (
        cd tests/work
        bad=$(${tools.findutils}/bin/find . \( -name '*.diff*' -o -name '*.base*' -o -name '*.log*' \) ! -type f -print -quit)
        test -z "$bad"
        ${tools.findutils}/bin/find . -type f \( -name '*.diff*' -o -name '*.base*' -o -name '*.log*' \) \
          -exec ${tools.coreutils}/bin/cp --parents --target-directory="$out/raw/work" -- {} +
      )
      exit "$status"
    '')
    // {
      enabled = final.doCheck;
      tools = environment.tools ++ [
        tools.gnutar
        tools.gzip
      ];
    };
  plan = final.productionPlan ++ [
    (steps.split "gnumake.finalize")
    (outputs.copyArtifacts { })
    {
      name = "gnumake.drop-build-tree";
      tools = [ tools.coreutils ];
      run = ''${tools.coreutils}/bin/rm -rf -- "$out/${checkpoint}"'';
    }
    {
      name = "gnumake.relocate";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../owned-split-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        lib.escapeShellArg (
          builtins.toJSON {
            slots = [
              [
                "${tools.bash}/bin/sh"
                "${final.runtime.shell}/bin/sh"
              ]
            ];
          }
        )
      } ${../../../lib/installed-tree.py}'';
    }
    {
      name = "output.manuals";
      tools = [ tools.gzip ];
      run = ''
        ${tools.gzip}/bin/gzip -n -9 "$out/share/man/man1/make.1"
        rm -f "$out/share/info/dir"
      '';
    }
    (outputs.strip {
      paths = [ "bin/make" ];
      flags = final.stripFlags;
    })
    (outputs.rpaths {
      paths = [ "bin/make" ];
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
    })
    (outputs.checkPaths { paths = [ "bin/make" ]; })
  ];
  meta = {
    description = "GNU Make build tool";
    license = lib.licenses.gpl3Plus;
    mainProgram = "make";
  };
}
