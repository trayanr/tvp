# Native source-GNU catalogue route; retained bootstrap procedure stays independent.
# 1.0.8 only: preserve the shared/static Makefile build and upstream CLI layout.
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
  python,
  binutils,
  patchelf,
  sed,
  grep,
  gawk,
  diffutils,
  findutils,
  doCheck ? true,
}:
let
  inherit (tvp.builder) steps outputs;
  elfPaths = [
    "bin/bzip2"
    "bin/bunzip2"
    "bin/bzcat"
    "bin/bzip2recover"
    "lib/libbz2.so.1.0.8"
  ];
in
final:
let
  environment = final.base.environment final.environment;
  command =
    name: run:
    environment
    // {
      inherit name run;
      cwd = "source";
    };
  make = ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash CC=cc'';
in
{
  pname = "bzip2";
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
    libraries = [ ];
    shell = bash;
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      inherit gzip findutils;
      tar = gnutar;
      compression = "gzip";
    })
    # Build the shared object first, as the retained recipe does. Upstream's
    # ordinary Makefile reuses those PIC objects for its static library.
    (command "bzip2.build" ''
      ${make} -f Makefile-libbz2_so
      ${make} libbz2.a bzip2 bzip2recover
    '')
    ((command "bzip2.check" "${make} check") // { enabled = doCheck; })
    (command "bzip2.install" ''
      ${make} install PREFIX="$out"
      for pair in 'bzegrep bzgrep' 'bzfgrep bzgrep' 'bzless bzmore' 'bzcmp bzdiff'; do
        set -- $pair
        ln -sfn "$2" "$out/bin/$1"
      done
      cp libbz2.so.1.0.8 "$out/lib/"
      ln -s libbz2.so.1.0.8 "$out/lib/libbz2.so.1.0"
      ln -s libbz2.so.1.0 "$out/lib/libbz2.so.1"
      ln -s libbz2.so.1.0 "$out/lib/libbz2.so"
      mkdir -p "$out/nix-support" "$out/share"
      mv "$out/man" "$out/share/man"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (outputs.strip {
      inherit python binutils;
      paths = elfPaths;
    })
    (outputs.stripArchives {
      inherit python binutils;
      paths = [ "lib/libbz2.a" ];
    })
    (outputs.shebangs {
      inherit python;
      paths = [
        "bin/bzgrep"
        "bin/bzmore"
        "bin/bzdiff"
      ];
      names = [ "sh" ];
      interpreter = "${final.runtime.shell}/bin/bash";
    })
    {
      name = "output.helper-paths";
      tools = [ python ];
      # The historical bzdiff calls /bin/rm directly. Use the caller's rm,
      # preserving these shell helpers' existing external utility contract.
      run = ''
        ${python}/bin/python3 - "$out/bin/bzdiff" <<'PY'
        import os
        from pathlib import Path
        import sys
        path = Path(sys.argv[1])
        info = path.stat()
        text = path.read_text()
        assert text.count('/bin/rm -f') == 1
        path.write_text(text.replace('/bin/rm -f', 'rm -f'))
        os.utime(path, ns=(info.st_atime_ns, info.st_mtime_ns))
        PY
      '';
    }
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      paths = elfPaths;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
    })
    (outputs.development {
      inherit python;
      libraries = [ ];
    })
    {
      name = "output.manuals";
      tools = [
        gzip
        findutils
      ];
      run = ''
        for path in "$out"/share/man/man1/*.1; do
          ${gzip}/bin/gzip -n -9 "$path"
        done
      '';
    }
    (outputs.checkSymlinks {
      inherit python;
      paths = [
        "lib/libbz2.so"
        "lib/libbz2.so.1"
        "lib/libbz2.so.1.0"
        "bin/bzegrep"
        "bin/bzfgrep"
        "bin/bzless"
        "bin/bzcmp"
      ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = elfPaths;
    })
  ];
  tvp.features = {
    shared = true;
    static = true;
  };
  meta = {
    description = "Bzip2 compression utility and library";
    license = lib.licenses.bsdOriginal;
    platforms = [ "x86_64-linux" ];
    mainProgram = "bzip2";
  };
}
