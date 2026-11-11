# Ordinary 1.13.0–1.13.1: explicit bootstrap and installed runtime bindings.
# The core executable requires TVP_NINJA_SHELL/PYTHON; no ambient fallback.
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
  buildShell,
}:
final:
let
  inherit (tvp.builder) steps outputs;
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
  finalCommand = name: run: (command name run) // { cwd = "."; };
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
  inherit
    helperPython
    gnutar
    gzip
    findutils
    patch
    sed
    binutils
    patchelf
    ;
  inherit
    python
    patches
    doCheck
    buildShell
    ;
  dependencyProviders = {
    bash = final.runtime.shell;
    python = final.runtime.python;
  };
  environment.tools = [
    final.helperPython
    final.patch
    final.sed
  ];
  runtime = {
    libraries = environment.libraries;
    shell = final.bash;
    python = final.python;
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.gnutar;
      gzip = final.gzip;
      findutils = final.findutils;
      compression = "gzip";
    })
    (command "ninja.prepare" ''
      ${lib.concatMapStringsSep "\n" (
        p: ''${final.patch}/bin/patch --batch --fuzz=0 -p1 < ${p}''
      ) final.patches}
    '')
    (steps.shebangs {
      name = "ninja.source-shells";
      python = final.helperPython;
      paths = [ "src/inline.sh" ];
      names = [ "sh" ];
      interpreter = "${final.buildShell}/bin/bash";
    })
    (command "ninja.build" ''
      mkdir -p "$out/.tvp-evidence"
      trap 'status=$?; if (( status != 0 )); then cat "$out/.tvp-evidence/build.log"; fi' EXIT
      export TVP_NINJA_SHELL=${final.buildShell}/bin/bash
      export TVP_NINJA_PYTHON=${final.helperPython}/bin/python3
      # Only the prepared compiler environment contributes flags.
      ${final.helperPython}/bin/python3 -B configure.py --bootstrap --verbose --with-python=${final.helperPython}/bin/python3 > "$out/.tvp-evidence/build.log" 2>&1
      cat "$out/.tvp-evidence/build.log" >&2
      cp build.ninja "$out/.tvp-evidence/"
    '')
    (
      (command "ninja.check" ''
        status=0
        ${final.helperPython}/bin/python3 -B misc/ninja_syntax_test.py -v > "$out/.tvp-evidence/check.log" 2>&1 || status=$?
        printf '%s\n' "$status" > "$out/.tvp-evidence/check.status"
        cat "$out/.tvp-evidence/check.log"
        test "$status" = 0
      '')
      // {
        enabled = final.doCheck;
      }
    )
    (command "ninja.install" ''
      install -Dm755 ninja "$out/bin/ninja"
      # Drop the unused /usr/bin/python shebang: this file is an imported module.
      tail -n +2 misc/ninja_syntax.py > ninja_syntax.py
      install -Dm644 ninja_syntax.py "$out/share/ninja/ninja_syntax.py"
      install -Dm644 doc/manual.asciidoc "$out/share/doc/ninja/manual.asciidoc"
      install -Dm644 ${../setup-hook.sh} "$out/nix-support/setup-hook"
      install -Dm644 COPYING "$out/share/licenses/ninja/COPYING"
    '')
    (command "ninja.remove-evidence" ''rm -rf "$out/.tvp-evidence"'')
    (steps.split "ninja.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    (finalCommand "ninja.place-core" ''
      mkdir "$out/libexec"
      mv "$out/bin/ninja" "$out/libexec/ninja"
    '')
    (outputs.template {
      python = final.helperPython;
      path = "bin/ninja";
      template = ../owned/ninja.sh;
      values = {
        shell = "${final.runtime.shell}/bin/bash";
        python = "${final.runtime.python}/bin/python3";
        out = "@OUTPUT@";
      };
    })
    (finalCommand "ninja.launcher-mode" ''chmod 755 "$out/bin/ninja"'')
    (outputs.strip {
      python = final.helperPython;
      binutils = final.binutils;
      paths = [ "libexec" ];
    })
    (outputs.rpaths {
      python = final.helperPython;
      binutils = final.binutils;
      patchelf = final.patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [ "libexec" ];
    })
    (outputs.checkPaths {
      python = final.helperPython;
      binutils = final.binutils;
      patchelf = final.patchelf;
      paths = [ "libexec" ];
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
