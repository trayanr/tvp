# Independent ordinary native zip 3.0 Unix generic procedure.
# Installation produces A; installed runtime and manual repair happen in F.
# The retained construction procedure keeps its original protocol.
{
  tvp,
  lib,
  base,
  src,
  version,
  binutils,
  bzip2,
  buildFeatures,
}:

final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs;
  baseTools = context.tools;
  inherit (final)
    bash
    coreutils
    gnumake
    gnutar
    gzip
    gnused
    gnugrep
    gawk
    diffutils
    findutils
    python
    patchelf
    ;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "zip.${name}";
      cwd = "source";
      run = ''
        export SHELL=${final.bash}/bin/bash CONFIG_SHELL=${final.bash}/bin/bash
        export NIX_HARDENING_ENABLE=${lib.escapeShellArg (lib.concatStringsSep " " (lib.subtractLists final.hardeningDisable final.base.compiler.defaultHardeningFlags))}
        # Some upstream probes omit CFLAGS entirely. The wrapper protocol reaches
        # every invocation, preserving the original probe and compiler profile.
        export NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE "${lib.escapeShellArg final.cflags}
        ${run}
      '';
    };
  make = ''
    ${gnumake}/bin/make -j"$NIX_BUILD_CORES" -f unix/Makefile SHELL=${final.bash}/bin/bash CC=cc \
        prefix="$out" BINDIR="$out/bin" MANDIR="$out/share/man/man1"'';
  elfPaths = [
    "bin/zip"
    "bin/zipnote"
    "bin/zipcloak"
    "bin/zipsplit"
  ];
in
{
  pname = "zip";
  inherit buildFeatures;
  cflags = final.buildFeatures.cflags;
  hardeningDisable = final.buildFeatures.hardeningDisable;
  bash = baseTools.bash;
  coreutils = baseTools.coreutils;
  gnumake = baseTools.gnumake;
  gnutar = baseTools.gnutar;
  gzip = baseTools.gzip;
  gnused = baseTools.sed;
  gnugrep = baseTools.grep;
  gawk = baseTools.gawk;
  diffutils = baseTools.diffutils;
  findutils = baseTools.findutils;
  python = baseTools.python;
  patchelf = baseTools.patchelf;

  inherit
    base
    src
    version
    ;
  environment = {
    tools = [
      gnumake
      gnused
      gnugrep
      gawk
      diffutils
      findutils
    ];
    libraries = [ bzip2 ];
  };
  runtime = {
    libraries = [ bzip2 ];
    shell = final.bash;
  };
  artifactPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit gzip findutils;
      compression = "gzip";
    })
    (command "prepare" ''
      # Make's flags rule explicitly calls sh, independently of its own SHELL.
      # Select the same shell for both and propagate SHELL through recursive make.
      ${python}/bin/python3 - <<'PYTHON'
      from pathlib import Path
      configure = Path('unix/configure')
      text = configure.read_text()
      assert text.startswith(':\n#!/bin/sh -x\n')
      configure.write_text(text.replace(':\n#!/bin/sh -x\n', '#!${final.bash}/bin/bash\n:\n', 1))
      p = Path('unix/Makefile')
      text = p.read_text()
      assert text.count('\tsh unix/configure ') == 1
      p.write_text(text.replace('\tsh unix/configure ', '\t${final.bash}/bin/bash unix/configure '))
      PYTHON
    '')
    (command "build" ''
      ${make} generic
      # Capture the selected probe and shell contract without a build-tree path.
      head -n1 unix/configure > source-shell
      printf '%s\n' ${final.bash}/bin/bash > make-shell
    '')
    (command "install" ''
      ${make} install
      mkdir -p "$out/nix-support"
      cp flags source-shell make-shell "$out/nix-support/"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/"
    '')
  ];
  plan = steps.sequence (
    final.artifactPlan
    ++ [
      (steps.split "zip.finalize")
      (outputs.copyArtifacts { coreutils = final.coreutils; })
      (outputs.strip {
        inherit python binutils;
        paths = elfPaths;
      })
      (outputs.rpaths {
        inherit python binutils patchelf;
        base = final.base;
        paths = elfPaths;
        libraries = final.runtime.libraries;
      })
      (outputs.development {
        inherit python;
        libraries = [ ];
      })
      {
        name = "output.manuals";
        tools = [ gzip ];
        run = ''for path in "$out"/share/man/man1/*.1; do ${gzip}/bin/gzip -n -9 "$path"; done'';
      }
      (outputs.checkPaths {
        inherit python binutils patchelf;
        paths = elfPaths;
      })
    ]
  );
  tvp.features = {
    bzip2 = true;
    encryption = true;
    zip64 = true;
    largeFiles = true;
  };
  meta = {
    description = "Info-ZIP archive creator";
    homepage = "https://infozip.sourceforge.net/";
    license = lib.licenses.info-zip;
    platforms = [ "x86_64-linux" ];
    mainProgram = "zip";
  };
}
