# Bzip2 1.0.6–1.0.7: release-named libbz2, unlike pinned construction 1.0.8.
# Preserve upstream Makefiles and PIC/static/shared interfaces; finalize after install.
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

in
final:
let
  elfPaths = [
    "bin/bzip2"
    "bin/bunzip2"
    "bin/bzcat"
    "bin/bzip2recover"
    "lib/libbz2.so.${final.version}"
  ];
  environment = final.base.environment final.environment;
  command =
    name: run:
    environment
    // {
      inherit name run;
      cwd = "source";
    };
  make = ''${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash CC=cc'';
  rpaths =
    {
      python,
      binutils,
      patchelf,
      base,
      paths,
      libraries,
      dlopenDirectories ? [ ],
    }:
    {
      name = "output.rpaths";
      tools = [
        python
        binutils
        patchelf
      ];
      run = ''${python}/bin/python3 -B ${../../../libraries/ordinary-compression-rpaths.py} "$out" ${
        lib.escapeShellArg (
          builtins.toJSON {
            inherit paths dlopenDirectories;
            elfKinds = null;
            libraries = lib.concatMap (
              p: (p.development or { }).libraryDirectories or [ "${lib.getLib p}/lib" ]
            ) libraries;
            baseDirectories = base.runtimeDirectories;
            readelf = "${binutils}/bin/readelf";
            patchelf = "${patchelf}/bin/patchelf";
          }
        )
      } ${../../../../lib/native-output}'';
    };

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
  tools = {
    inherit
      gnumake
      gnutar
      gzip
      findutils
      python
      binutils
      patchelf
      sed
      grep
      gawk
      diffutils
      ;
  };
  libraries = { };
  inherit doCheck;
  stripFlags = [
    "-S"
    "-p"
  ];
  dependencyProviders = final.tools // final.libraries;
  environment = {
    tools = [
      final.tools.gnumake
      final.tools.sed
      final.tools.grep
      final.tools.gawk
      final.tools.diffutils
      final.tools.findutils
    ];
    libraries = [ ];
  };
  runtime = {
    libraries = [ ];
    shell = final.bash;
    pager = final.coreutils;
    tools = [
      final.coreutils
      final.tools.sed
      final.tools.grep
      final.tools.diffutils
    ];
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      gzip = final.tools.gzip;
      findutils = final.tools.findutils;
      tar = final.tools.gnutar;
      compression = "gzip";
    })
    # Build the shared object first, as the retained recipe does. Upstream's
    # ordinary Makefile reuses those PIC objects for its static library.
    {
      name = "bzip2.prepare";
      cwd = "source";
      tools = [ final.tools.python ];
      env = environment.env;
      run = ''${final.tools.python}/bin/python3 -B ${../../../libraries/ordinary-compression-source.py} bzip2 ${final.bash}/bin/bash'';
    }
    (command "bzip2.build" ''
      ${make} -f Makefile-libbz2_so
      ${make} libbz2.a bzip2 bzip2recover
    '')
    ((command "bzip2.check" "${make} check") // { enabled = final.doCheck; })
    (command "bzip2.install" ''
      ${make} install PREFIX="$out"
      cp libbz2.so.${final.version} "$out/lib/"
      ln -s libbz2.so.${final.version} "$out/lib/libbz2.so.1.0"
      ln -s libbz2.so.1.0 "$out/lib/libbz2.so.1"
      ln -s libbz2.so.1.0 "$out/lib/libbz2.so"
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "bzip2.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "bzip2.relocate-runtime";
      tools = [
        final.tools.python
        final.tools.patchelf
      ];
      run = ''${final.tools.python}/bin/python3 -B ${../../../libraries/ordinary-compression-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${final.tools.patchelf}/bin/patchelf ${
        lib.escapeShellArg (
          builtins.toJSON {
            family = "bzip2";
            buildShell = "${final.bash}/bin/bash";
            shell = "${final.runtime.shell}/bin/bash";
            pager = "${final.runtime.pager}/bin/cat";
            paths = map (p: "${p}/bin") final.runtime.tools;
          }
        )
      }'';
    }
    (outputs.strip {
      flags = final.stripFlags;
      python = final.tools.python;
      binutils = final.tools.binutils;
      paths = elfPaths;
    })
    (outputs.stripArchives {
      python = final.tools.python;
      binutils = final.tools.binutils;
      paths = [ "lib/libbz2.a" ];
    })
    (outputs.shebangs {
      python = final.tools.python;
      paths = [
        "bin/bzgrep"
        "bin/bzmore"
        "bin/bzdiff"
      ];
      names = [ "sh" ];
      interpreter = "${final.runtime.shell}/bin/bash";
    })
    (rpaths {
      python = final.tools.python;
      binutils = final.tools.binutils;
      patchelf = final.tools.patchelf;
      base = final.base;
      paths = elfPaths;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
    })
    (outputs.development {
      python = final.tools.python;
      libraries = [ ];
    })
    {
      name = "output.manuals";
      tools = [
        final.tools.gzip
        final.tools.findutils
      ];
      run = ''
        for path in "$out"/share/man/man1/*.1; do
          ${final.tools.gzip}/bin/gzip -n -9 "$path"
        done
      '';
    }
    (outputs.checkSymlinks {
      python = final.tools.python;
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
      python = final.tools.python;
      binutils = final.tools.binutils;
      patchelf = final.tools.patchelf;
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
    platforms = lib.platforms.unix;
    mainProgram = "bzip2";
  };
}
