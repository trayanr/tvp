# Complete supported M4 procedure. Only 1.4.19 supplies a dialect exception.
{
  tvp,
  lib,
  base,
  src,
  version,
  cStandard ? null,
  configureFlags ? [ ],
  doCheck ? true,
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
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
  checkpoint = "nix-support/m4-build-tree";
  preparation = steps.shebangs {
    name = "m4.upstream-shells";
    cwd = ".";
    paths = [
      "checks"
      "tests"
    ];
    names = [ "sh" ];
    interpreter = "${tools.bash}/bin/bash";
  };
in
{
  pname = "m4";
  # Equal-width artifact/final names preserve every installed prefix field.
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    cStandard
    configureFlags
    doCheck
    ;
  inherit (tools) bash coreutils;
  sourceLayout.scripts = [ "build-aux" ];
  environment = {
    tools = [
      tools.gnumake
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
    ];
    libraries = [ ];
    overrides = lib.optionalAttrs (final.cStandard != null) {
      flags.NIX_CFLAGS_COMPILE = [ "-std=${final.cStandard}" ];
    };
  };
  runtime = {
    libraries = final.environment.libraries or [ ];
    shell = tools.bash;
  };
  productionPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (steps.prepareAutotools { name = "m4.prepare"; })
    (steps.shebangs {
      name = "m4.source-shells";
      paths = final.sourceLayout.scripts;
      names = [ "sh" ];
      interpreter = "${tools.bash}/bin/bash";
    })
    (command "m4.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash
      ./configure --prefix="$out" --with-syscmd-shell=${tools.bash}/bin/bash ${lib.escapeShellArgs final.configureFlags}
    '')
    (
      (command "m4.shell-slot" ''${tools.python}/bin/python3 -B ${./shell-slot.py} lib/config.h'')
      // {
        tools = environment.tools ++ [ tools.python ];
      }
    )
    (command "m4.build" ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'')
    (command "m4.install" ''
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (
      (command "m4.save-build-tree" ''
        ${tools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/${checkpoint}"
      '')
      // {
        tools = environment.tools ++ [ tools.python ];
      }
    )
  ];
  upstreamPlan = artifact: [
    {
      name = "m4.restore-build-tree";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${./tests/restore.py} ${artifact}/${checkpoint} "$TVP_SOURCE_ROOT"'';
    }
    (
      preparation
      // {
        run = ''
          cd "$(cat "$TVP_SOURCE_ROOT/tree-path")"
          ${preparation.run}
        '';
      }
    )
  ];
  upstreamCheck =
    (command "m4.check" ''
      ${tools.python}/bin/python3 -B ${./tests/check.py} ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash check
    '')
    // {
      enabled = final.doCheck;
      tools = environment.tools ++ [ tools.python ];
    };
  plan = final.productionPlan ++ [
    (steps.split "m4.finalize")
    (outputs.copyArtifacts { })
    {
      name = "m4.drop-build-tree";
      tools = [ tools.coreutils ];
      run = ''${tools.coreutils}/bin/rm -rf -- "$out/${checkpoint}"'';
    }
    {
      name = "m4.relocate";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../owned-split-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        lib.escapeShellArg (
          builtins.toJSON {
            slots = [
              [
                "${tools.bash}/bin/bash"
                "${final.runtime.shell}/bin/bash"
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
        ${tools.gzip}/bin/gzip -n -9 "$out/share/man/man1/m4.1"
        rm -f "$out/share/info/dir"
      '';
    }
    (outputs.strip { paths = [ "bin/m4" ]; })
    (outputs.rpaths {
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [ "bin/m4" ];
    })
    (outputs.checkPaths { paths = [ "bin/m4" ]; })
  ];
  meta = {
    description = "GNU macro processor";
    homepage = "https://www.gnu.org/software/m4/";
    license = lib.licenses.gpl3Plus;
    mainProgram = "m4";
  };
}
