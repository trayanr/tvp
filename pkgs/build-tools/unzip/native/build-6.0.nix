# Independent ordinary native unzip 6.0 Unix generic procedure.
# Installation produces A; installed runtime and manual repair happen in F.
# The retained construction procedure keeps its original protocol.
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
  gnused,
  gnugrep,
  gawk,
  diffutils,
  findutils,
  python,
  binutils,
  patchelf,
  cflags,
  hardeningDisable,
  doCheck ? true,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "unzip.${name}";
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
    "bin/unzip"
    "bin/funzip"
    "bin/unzipsfx"
  ];
in
{
  pname = "unzip";
  inherit
    base
    src
    version
    bash
    coreutils
    cflags
    hardeningDisable
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
    libraries = [ ];
  };
  runtime = {
    libraries = [ ];
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

      install -Dm644 ${../setup-hook.sh} "$out/nix-support/setup-hook"
    '')
  ];
  inherit doCheck;
  upstreamPlan = steps.sequence [
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
  ];
  upstreamCheck =
    (command "check" ''
      # The shipped target exits zero with a stale zipinfo-format fixture.
      # Preserve that nonpass explicitly; accept only this exact known mismatch.
      # Extraction/funzip/SFX byte semantics also have installed-output tests.
      export TZ=CET-1CEST,M3.5.0,M10.5.0/3
      ${make} check > upstream-check.log 2>&1
      cat upstream-check.log
      if grep -F '#####  ERROR:' upstream-check.log; then exit 1; fi
      test "$(grep -c '#####  WARNING:' upstream-check.log)" = 1
      grep -Fx "#####  WARNING:  zipinfo output doesn't match stored version" upstream-check.log
      ./unzip -Z testmake.zip > upstream-zipinfo.actual
      ./unzip -p testmake.zip testmake.zipinfo > upstream-zipinfo.expected
      ${python}/bin/python3 - <<'PYTHON'
      from pathlib import Path
      expected = Path('upstream-zipinfo.expected').read_text()
      actual = Path('upstream-zipinfo.actual').read_text()
      assert expected != actual
      normalized = expected.replace('Archive:  testmake.zip   527 bytes   2 files\n',
          'Archive:  testmake.zip\nZip file size: 527 bytes, number of entries: 2\n')
      normalized = normalized.replace('19-Nov-98', '98-Nov-19')
      assert normalized == actual, 'unexpected upstream fixture difference'
      PYTHON
      printf '0\n' > upstream-check.status
      printf '1\n' > upstream-strict.status
      printf '%s\n' 'KNOWN-NONPASS: stale 1998 zipinfo header/date fixture; raw make check exits 0' > upstream-qualification
    '')
    // {
      enabled = final.doCheck;
    };
  plan = steps.sequence (
    final.artifactPlan
    ++ [
      (steps.split "unzip.finalize")
      (outputs.copyArtifacts { coreutils = final.coreutils; })
      (outputs.shebangs {
        inherit python;
        paths = [ "bin/zipgrep" ];
        names = [ "sh" ];
        interpreter = "${final.runtime.shell}/bin/bash";
      })
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
      {
        name = "output.zipinfo-link";
        # Upstream installs a hard link. Stripping or ELF rewriting may replace
        # an inode, so restore the alias to the finalized executable explicitly.
        run = ''
          test ! -L "$out/bin/zipinfo"
          ln -f "$out/bin/unzip" "$out/bin/zipinfo"
          test "$out/bin/unzip" -ef "$out/bin/zipinfo"
        '';
      }
      (outputs.checkPaths {
        inherit python binutils patchelf;
        paths = elfPaths;
      })
    ]
  );
  tvp.features = {
    bzip2 = false;
    encryption = true;
    zip64 = true;
    largeFiles = true;
  };
  meta = {
    description = "Info-ZIP archive extractor";
    homepage = "https://infozip.sourceforge.net/";
    license = lib.licenses.info-zip;
    platforms = [ "x86_64-linux" ];
    mainProgram = "unzip";
  };
}
