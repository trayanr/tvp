# Complete ordinary Ninja procedure: bootstrap A, installed F, independent U.
{
  tvp,
  lib,
  base,
  src,
  version,
  runtimeShell,
  browsePython,
  patches,
  doCheck ? true,
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  # Fixed-width paths preserve C++ embedded string lengths for runtime edits.
  padded =
    path:
    assert builtins.stringLength path <= 256;
    builtins.concatStringsSep "" (builtins.genList (_: "/") (256 - builtins.stringLength path)) + path;
  buildShell = padded "${tools.bash}/bin/bash";
  finalShell = padded "${final.runtime.shell}/bin/bash";
  buildPython = padded "${tools.python}/bin/python3";
  finalPython = padded "${final.runtime.python}/bin/python3";
  checkpoint = "nix-support/ninja-build-tree";
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
        CFLAGS = environment.env.CFLAGS or (lib.concatStringsSep " " compileFlags);
        CXXFLAGS = environment.env.CXXFLAGS or (lib.concatStringsSep " " compileFlags);
        LDFLAGS = environment.env.LDFLAGS or (lib.concatMapStringsSep " " (f: "-Wl,${f}") linkFlags);
      };
    };
in
{
  pname = "ninja";
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    runtimeShell
    browsePython
    patches
    doCheck
    ;
  inherit (tools) bash coreutils;
  dependencyProviders = {
    runtimeShell = final.runtime.shell;
    browsePython = final.runtime.python;
  };
  environment.tools = [
    tools.python
    tools.patch
    tools.sed
  ];
  runtime = {
    libraries = environment.libraries;
    shell = final.runtimeShell;
    python = final.browsePython;
    dlopenDirectories = [ ];
  };
  productionPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (command "ninja.prepare" ''
      ${tools.python}/bin/python3 -B ${../source-targets.py} src/subprocess-posix.cc src/inline.sh
      ${lib.concatMapStringsSep "\n" (
        patch: "${tools.patch}/bin/patch --batch --fuzz=0 -p1 < ${patch}"
      ) final.patches}
      ${tools.python}/bin/python3 -B ${./prepare.py} ${lib.escapeShellArg buildShell}
    '')
    (steps.shebangs {
      name = "ninja.source-shells";
      paths = [ "src/inline.sh" ];
      names = [ "sh" ];
      interpreter = "${tools.bash}/bin/bash";
    })
    (command "ninja.build" ''
      trap 'status=$?; if (( status != 0 )); then cat build.log >&2; fi' EXIT
      ${tools.python}/bin/python3 -B configure.py --bootstrap --verbose \
        --with-python=${lib.escapeShellArg buildPython} > build.log 2>&1
      cat build.log >&2
    '')
    (command "ninja.install" ''
      install -Dm755 ninja "$out/bin/ninja"
      install -Dm644 misc/ninja_syntax.py "$out/share/ninja/ninja_syntax.py"
      install -Dm644 doc/manual.asciidoc "$out/share/doc/ninja/manual.asciidoc"
      install -Dm644 ${./setup-hook.sh} "$out/nix-support/setup-hook"
      install -Dm644 COPYING "$out/share/licenses/ninja/COPYING"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (
      (command "ninja.save-build-tree" ''
        ${tools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/${checkpoint}"
      '')
      // {
        tools = environment.tools ++ [ tools.python ];
      }
    )
  ];
  upstreamPlan = artifact: [
    {
      name = "ninja.restore-build-tree";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${./tests/restore.py} ${artifact}/${checkpoint} "$TVP_SOURCE_ROOT"'';
    }
  ];
  # Preserve the existing upstream scope: Python syntax module tests. C++ tests
  # require GoogleTest, which is not provided by these source archives.
  upstreamCheck =
    (command "ninja.check" ''
      ${tools.python}/bin/python3 -B misc/ninja_syntax_test.py -v
    '')
    // {
      enabled = final.doCheck;
    };
  plan = final.productionPlan ++ [
    (steps.split "ninja.finalize")
    (outputs.copyArtifacts { })
    {
      name = "ninja.drop-build-tree";
      tools = [ tools.coreutils ];
      run = ''${tools.coreutils}/bin/rm -rf -- "$out/${checkpoint}"'';
    }
    {
      name = "ninja.relocate";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../owned-split-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        lib.escapeShellArg (
          builtins.toJSON {
            fixed = [
              [
                buildShell
                finalShell
              ]
              [
                buildPython
                finalPython
              ]
            ];
          }
        )
      } ${../../../lib/installed-tree.py}'';
    }
    {
      name = "ninja.module-header";
      tools = [ tools.coreutils ];
      run = ''
        # This installed file is imported source data, not an executable script.
        tail -n +2 "$out/share/ninja/ninja_syntax.py" > ninja_syntax.py
        cp ninja_syntax.py "$out/share/ninja/ninja_syntax.py"
      '';
    }
    (outputs.strip { paths = [ "bin" ]; })
    (outputs.rpaths {
      paths = [ "bin" ];
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
    })
    (outputs.checkPaths { paths = [ "bin" ]; })
  ];
  meta = {
    homepage = "https://ninja-build.org/";
    description = "Small build system focused on speed";
    license = lib.licenses.asl20;
    mainProgram = "ninja";
  };
}
