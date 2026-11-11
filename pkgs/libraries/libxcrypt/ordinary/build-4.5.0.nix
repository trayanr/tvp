# Libxcrypt 4.5.0–4.5.1: extended obsolete-API configuration, without the
# 4.4.36 GCC15+ diagnostic exception. Complete ordinary procedure; defaults
# retain all upstream hash formats, compatibility APIs, shared/static libraries.
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
  xz,
  perl,
  python,
  binutils,
  patchelf,
  gzip,
  sed,
  grep,
  gawk,
  diffutils,
  findutils,
  compileFlags ? [ ],
  doCheck ? true,
}:
let
  inherit (tvp.builder) steps outputs;
in
final:
let
  elfPaths = [ "lib/libcrypt.so.1.1.0" ];
  environment = final.base.environment final.environment;
  command =
    name: run:
    environment
    // {
      inherit name;
      run =
        ''
          export NIX_CFLAGS_COMPILE="${lib.concatStringsSep " " (lib.optionals (lib.versionAtLeast final.base.compiler.version "15") final.compileFlags)} $NIX_CFLAGS_COMPILE"
        ''
        + run;
      cwd = "source";
    };
in
{
  pname = "libxcrypt";
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
    xz
    compileFlags
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
    xz = final.xz;
  };
  environment = {
    tools = [
      final.gnumake
      final.sed
      final.grep
      final.gawk
      final.diffutils
      final.findutils
      final.perl
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
      xz = final.xz;
      findutils = final.findutils;
      tar = final.gnutar;
    })
    (command "libxcrypt.prepare" ''
      ${final.python}/bin/python3 -B ${../../ordinary-attr-crypt-source.py} ${final.bash}/bin/bash ${final.perl}/bin/perl '["build-aux","test"]'
    '')
    (command "libxcrypt.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "libxcrypt.build" ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
    (
      (command "libxcrypt.check" ''
        status=0
        ${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" check || status=$?
        cat test-suite.log
        exit "$status"
      '')
      // {
        enabled = final.doCheck;
      }
    )
    (command "libxcrypt.install" ''
      ${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "libxcrypt.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "libxcrypt.relocate";
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
            requiredRegular = [
              "lib/libcrypt.a"
              "lib/libcrypt.la"
              "nix-support/propagated-build-inputs"
            ];
            libtoolData = [ "lib/libcrypt.la" ];
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
      run = ''find "$out/share/man" -type f -exec ${final.gzip}/bin/gzip -n -9 '{}' +'';
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
      paths = [ "lib/libcrypt.a" ];
    })
    (outputs.libtool {
      python = final.python;
      paths = [ "lib/libcrypt.la" ];
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
        "lib/libcrypt.so"
        "lib/libcrypt.so.1"
        "lib/libxcrypt.so"
        "lib/libowcrypt.so"
        "lib/libowcrypt.so.1"
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
    description = "Extended crypt library";
    homepage = "https://github.com/besser82/libxcrypt/";
    license = lib.licenses.lgpl21Plus;
    platforms = lib.platforms.unix;
  };
}
