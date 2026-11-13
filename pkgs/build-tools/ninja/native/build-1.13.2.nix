# Native ordinary 1.13.2 retains browse with full public Python and the selected shell.
{
  lib,
  tvp,
  base,
  src,
  version,
  bash,
  coreutils,
  python,
  helperPython,
  gnutar,
  gzip,
  findutils,
  patch,
  sed,
  binutils,
  patchelf,
  patches,
  doCheck ? true,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  # Fixed-width valid paths preserve C++ string lengths, including CMake's
  # generated Makefile fragments. The selected build shell runs during bootstrap.
  padded =
    path:
    assert builtins.stringLength path <= 256;
    lib.concatStrings (lib.replicate (256 - builtins.stringLength path) "/") + path;
  buildShell = padded "${final.bash}/bin/bash";
  runtimeShell = padded "${final.runtime.shell}/bin/bash";
  buildPython = padded "${python}/bin/python3";
  runtimePython = padded "${final.runtime.python}/bin/python3";
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
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  environment.tools = [
    helperPython
    patch
    sed
  ];
  runtime = {
    libraries = environment.libraries;
    shell = final.bash;
    inherit python;
  };
  upstreamCheck = {
    enabled = doCheck;
    before = "ninja.install";
    command = (
      (command "ninja.check" ''
        status=0
        ${helperPython}/bin/python3 -B misc/ninja_syntax_test.py -v > "$out/.tvp-evidence/check.log" 2>&1 || status=$?
        printf '%s\n' "$status" > "$out/.tvp-evidence/check.status"
        cat "$out/.tvp-evidence/check.log"
        test "$status" = 0
      '')
      // {
        enabled = doCheck;
      }
    );
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit gzip findutils;
      compression = "gzip";
    })
    (command "ninja.prepare" ''
      ${lib.concatMapStringsSep "\n" (p: "${patch}/bin/patch --batch --fuzz=0 -p1 < ${p}") patches}
      ${helperPython}/bin/python3 -B - ${lib.escapeShellArg buildShell} <<'PY'
      from pathlib import Path
      import sys
      p = Path('src/subprocess-posix.cc')
      text = p.read_text()
      assert text.count('@TVP_SHELL@') == 2
      p.write_text(text.replace('@TVP_SHELL@', sys.argv[1]))
      PY
    '')
    (steps.shebangs {
      name = "ninja.source-shells";
      python = helperPython;
      paths = [ "src/inline.sh" ];
      names = [ "sh" ];
      interpreter = "${final.bash}/bin/bash";
    })
    (command "ninja.build" ''
      mkdir -p "$out/.tvp-evidence"
      trap 'status=$?; if (( status != 0 )); then cat "$out/.tvp-evidence/build.log"; fi' EXIT
      # Only the prepared compiler environment contributes flags.
      ${helperPython}/bin/python3 -B configure.py --bootstrap --verbose --with-python=${lib.escapeShellArg buildPython} > "$out/.tvp-evidence/build.log" 2>&1
      cp build.ninja "$out/.tvp-evidence/"
    '')
    (command "ninja.install" ''
      install -Dm755 ninja "$out/bin/ninja"
      install -Dm644 misc/ninja_syntax.py "$out/share/ninja/ninja_syntax.py"
      install -Dm644 doc/manual.asciidoc "$out/share/doc/ninja/manual.asciidoc"
      install -Dm644 ${../setup-hook.sh} "$out/nix-support/setup-hook"
      install -Dm644 COPYING "$out/share/licenses/ninja/COPYING"
    '')
    (steps.split "ninja.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "ninja.relocate";
      tools = [ helperPython ];
      run = ''${helperPython}/bin/python3 -B ${../../owned-split-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        lib.escapeShellArg (
          builtins.toJSON {
            fixed = [
              [
                buildShell
                runtimeShell
              ]
              [
                buildPython
                runtimePython
              ]
            ];
            text = [
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
      name = "ninja.module-header";
      run = ''
        # This file is an imported module; discard only its unused script header.
        tail -n +2 "$out/share/ninja/ninja_syntax.py" > ninja_syntax.py
        cp ninja_syntax.py "$out/share/ninja/ninja_syntax.py"
      '';
    }
    {
      name = "ninja.remove-evidence";
      run = ''rm -rf "$out/.tvp-evidence"'';
    }
    (outputs.strip {
      python = helperPython;
      inherit binutils;
      paths = [ "bin" ];
    })
    (outputs.rpaths {
      python = helperPython;
      inherit binutils patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [ "bin" ];
    })
    (outputs.checkPaths {
      python = helperPython;
      inherit binutils patchelf;
      paths = [ "bin" ];
    })
  ];
  meta = {
    homepage = "https://ninja-build.org/";
    description = "Small build system focused on speed";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "ninja";
  };
}
