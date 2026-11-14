# Attr 2.5.0–2.5.2 share the measured configure/test/install procedure.
# Explicit definition data selects the shipped 250/2501/2502 library revisions.
# The .test harness predates 2.6.0's .run interface. Retained construction unchanged.
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
  perl,
  binutils,
  patchelf,
  sed,
  grep,
  gawk,
  diffutils,
  findutils,
  libraryFile,
  doCheck ? true,
}:
let
  inherit (tvp.builder) steps outputs;
in
final:
let
  elfPaths = [
    "bin"
    "lib/${final.libraryFile}"
  ];
  environment = final.base.environment final.environment;
  command =
    name: run:
    environment
    // {
      inherit name run;
      cwd = "source";
    };
in
{
  pname = "attr";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  inherit
    gnumake
    gnutar
    gzip
    python
    perl
    binutils
    patchelf
    sed
    grep
    gawk
    diffutils
    findutils
    libraryFile
    doCheck
    ;
  features = {
    shared = true;
    static = true;
  };
  configureFlags = [
    (if final.features.shared then "--enable-shared" else "--disable-shared")
    (if final.features.static then "--enable-static" else "--disable-static")
  ];
  stripFlags = [
    "-S"
    "-p"
  ];
  dependencyProviders = {
    bash = final.bash;
    coreutils = final.coreutils;
    gnumake = final.gnumake;
    gnutar = final.gnutar;
    gzip = final.gzip;
    python = final.python;
    perl = final.perl;
    binutils = final.binutils;
    patchelf = final.patchelf;
    sed = final.sed;
    grep = final.grep;
    gawk = final.gawk;
    diffutils = final.diffutils;
    findutils = final.findutils;
  };
  environment = {
    tools = [
      final.gnumake
      final.sed
      final.grep
      final.gawk
      final.diffutils
      final.findutils
    ];
    libraries = [ ];
  };
  runtime.shell = final.bash;
  runtime.tools = [
    final.coreutils
    final.sed
    final.grep
    final.gawk
    final.diffutils
    final.findutils
  ];
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      gzip = final.gzip;
      findutils = final.findutils;
      tar = final.gnutar;
      compression = "gzip";
    })
    (command "attr.prepare" ''
      ${final.python}/bin/python3 -B ${../../ordinary-attr-crypt-source.py} ${final.bash}/bin/bash ${final.perl}/bin/perl '["build-aux","test"]'
    '')
    (command "attr.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      export lt_cv_deplibs_check_method=pass_all
      ./configure --prefix="$out" ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "attr.build" ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
    (
      (command "attr.check" ''
        "$CC" ${../../../../lib/tests/filesystem-capabilities.c} -o .tvp-filesystem-probe
        status=0
        ${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" check \
          TEST_LOG_COMPILER="${final.python}/bin/python3 -B ${./test-runner.py} $PWD/.tvp-filesystem-probe $PWD/test/run" \
          || status=$?
        cat test-suite.log
        exit "$status"
      '')
      // {
        enabled = final.doCheck;
        tools = environment.tools ++ [
          final.perl
          final.python
        ];
      }
    )
    (command "attr.install" ''
      ${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "attr.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "attr.relocate";
      tools = [
        final.python
        final.binutils
        final.patchelf
      ];
      run = ''${final.python}/bin/python3 -B ${../../ordinary-attr-crypt-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${final.patchelf}/bin/patchelf ${
        lib.escapeShellArg (
          builtins.toJSON {
            readelf = "${final.binutils}/bin/readelf";
            shell = "${final.runtime.shell}/bin/bash";
            requiredDirectories = [
              "lib"
              "share/man"
              "nix-support"
              "bin"
            ];
            requiredFiles = [
              "lib/libattr.a"
              "lib/libattr.la"
              "lib/${final.libraryFile}"
            ];
            requiredRegular = [
              "lib/libattr.a"
              "lib/libattr.la"
              "nix-support/propagated-build-inputs"
            ];
            libtoolData = [ "lib/libattr.la" ];
            buildShell = "${final.bash}/bin/bash";
            paths = map (p: "${p}/bin") final.runtime.tools;
          }
        )
      }'';
    }
    {
      name = "output.manuals";
      tools = [
        final.gzip
        final.findutils
      ];
      run = ''
        while IFS= read -r -d $'\0' manual; do
          ${final.gzip}/bin/gzip -n -9 "$manual"
        done < <(find "$out/share/man" -type f ! -name '*.gz' -print0)
        while IFS= read -r -d "" manual; do
          target=$(readlink "$manual")
          rm "$manual"
          ln -s "$target.gz" "$manual.gz"
        done < <(find "$out/share/man" -type l ! -name '*.gz' -print0)
      '';
    }
    (outputs.strip {
      flags = final.stripFlags;
      python = final.python;
      binutils = final.binutils;
      paths = elfPaths;
    })
    (outputs.stripArchives {
      python = final.python;
      binutils = final.binutils;
      paths = [ "lib/libattr.a" ];
    })
    (outputs.libtool {
      python = final.python;
      paths = [ "lib/libattr.la" ];
    })
    ((import ../../ordinary-attr-crypt-rpaths.nix { inherit lib; }) {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = elfPaths;
    })
    (outputs.development {
      python = final.python;
      libraries = [ ];
    })
    (outputs.checkSymlinks {
      python = final.python;
      paths = [
        "lib/libattr.so"
        "lib/libattr.so.1"
      ];
    })
    ((import ../../ordinary-attr-crypt-check-paths.nix { inherit lib; }) {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      paths = elfPaths;
    })
  ];
  tvp.features = final.features;
  meta = {
    description = "Extended attribute utilities and library";
    license = lib.licenses.lgpl21Plus;
    platforms = lib.platforms.unix;
  };
}
