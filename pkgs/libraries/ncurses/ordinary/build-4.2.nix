# Ncurses 4.2–5.7: historical wide names, no pkg-config, optional old C++ bindings.
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
  python,
  binutils,
  patchelf,
  sed,
  grep,
  gawk,
  diffutils,
  findutils,
  gzip,
  pkgConfig,
  perl,
  doCheck ? true,
  patch,
  patches ? [ ],
  hardeningDisable ? [ "format" ],
  gnu-config,
  cxxBinding ? true,
  cStandard ? "gnu89",
  cxxStandard ? "gnu++98",
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "ncurses.${name}";
      cwd = "source";
      inherit run;
    };
in
{
  pname = "ncurses";
  # Retain this generation's format exception on the selected owned adapters.
  base =
    if base.compiler ? hardeningPolicy then
      let
        policy = base.compiler.specification.policy // {
          disable = final.hardeningDisable;
        };
        bintools = base.compiler.bintools.override { inherit policy; };
        compiler = base.compiler.override { inherit policy bintools; };
      in
      base.override { inherit compiler; }
    else
      base;
  inherit
    src
    version
    bash
    coreutils
    gnumake
    gnutar
    python
    binutils
    patchelf
    sed
    grep
    gawk
    diffutils
    findutils
    gzip
    pkgConfig
    perl
    doCheck
    patch
    patches
    hardeningDisable
    gnu-config
    cxxBinding
    cStandard
    cxxStandard
    ;
  features = {
    finalizationContracts = false;
    modernInterfaces = false;
    cStandard = final.cStandard;
    cxxStandard = final.cxxStandard;
    widec = true;
    cxx = final.cxxBinding && lib.versionAtLeast final.version "5.0";
    constUserData = final.cxxBinding && lib.versionAtLeast final.version "5.3";
    pkgConfig = false;
    libName = if lib.versionAtLeast final.version "5.1" then "ncursesw" else "ncurses";
    shared = true;
    static = true;
  };
  configureFlags = [
    "--mandir=${placeholder "out"}/share/man"
    (if final.features.shared then "--with-shared" else "--without-shared")
    (if final.features.static then "--with-normal" else "--without-normal")
    (if final.features.widec then "--enable-widec" else "--disable-widec")
  ] ++ lib.optional (!final.cxxBinding) "--without-cxx-binding";

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
  development.includeDirectories = [
    "include/${final.features.libName}"
    "include"
  ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.gnutar;
      gzip = final.gzip;
      findutils = final.findutils;
      compression = "gzip";
    })
    (command "patch.sources" ''
      for file in ${lib.escapeShellArgs (map (p: "${p}") final.patches)}; do
        ${final.patch}/bin/patch -p1 < "$file"
      done
    '')
    (command "prepare" ''
      # 4.2's executable clear.sh is a one-line shell body without a header.
      # Adapt this known historical frontend before the confined shell mutator.
      ${final.python}/bin/python3 -B - <<'PYTHON'
      from pathlib import Path
      p = Path('progs/clear.sh')
      data = p.read_bytes()
      if not data.startswith(b'#!'):
          assert data == b'exec tput clear\n', 'unexpected historical clear frontend'
          p.write_bytes(b'#!/bin/sh\n' + data)
      PYTHON
      cp ${final.gnu-config}/config.guess ${final.gnu-config}/config.sub .
      chmod +w config.guess config.sub
      ${final.sed}/bin/sed -i 's/1\*|2\./1.*|2./g' configure
      for generator in ncurses/MKlib_gen.sh ncurses/base/MKlib_gen.sh; do
        if test -f "$generator"; then
          ${final.sed}/bin/sed -i 's/preprocessor="$1 /preprocessor="$1 -P /' "$generator"
        fi
      done
      ${final.sed}/bin/sed -i 's|SRC_SUBDIRS="$SRC_SUBDIRS misc test"|SRC_SUBDIRS="$SRC_SUBDIRS misc"|' configure
      helpers=(configure config.guess config.sub install-sh misc progs include ncurses c++ man)
      if test -f mkinstalldirs; then helpers+=(mkinstalldirs); fi
      selections=$(${final.python}/bin/python3 -c 'import json, sys; print(json.dumps(sys.argv[1:]))' "''${helpers[@]}")
      ${final.python}/bin/python3 -B ${./source.py} ${final.bash}/bin/bash ${final.perl}/bin/perl "$selections"
    '')
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash FORCE_UNSAFE_CONFIGURE=1
      export CFLAGS="''${CFLAGS:--O2} -std=${final.cStandard}"
      ${lib.optionalString (
        final.cxxStandard != null
      ) ''export CXXFLAGS="''${CXXFLAGS:--O2} -std=${final.cxxStandard}"''}
      ./configure --prefix="$out" ${lib.escapeShellArgs final.configureFlags} --without-debug
    '')
    # Configure emits headers.sh with a literal /bin/sh interpreter.
    (steps.shebangs {
      name = "ncurses.install-helpers";
      python = final.python;
      paths = [ "headers.sh" ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (command "build" ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'')
    # Upstream supplies interactive test programs; installed C/C++/database
    # consumers are exercised by the ordinary suite instead of a make check target.
    (command "install" ''
      ${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "ncurses.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "ncurses.relocate";
      tools = [
        final.python
        final.binutils
        final.patchelf
      ];
      run = ''${final.python}/bin/python3 -B ${./output.py} "$out" "$TVP_ARTIFACT_ROOT" ${final.patchelf}/bin/patchelf ${
        lib.escapeShellArg (
          builtins.toJSON {
            readelf = "${final.binutils}/bin/readelf";
            shell = "${final.runtime.shell}/bin/bash";
            buildShell = "${final.bash}/bin/bash";
            paths = map (p: "${p}/bin") final.runtime.tools;
            requiredDirectories = [
              "lib"
              "include"
              "share/man"
              "nix-support"
            ];
            requiredFiles = [ "lib/lib${final.features.libName}.a" ];
            requiredRegular = [ "lib/lib${final.features.libName}.a" ];
          }
        )
      }'';
    }
    {
      name = "ncurses.manuals";
      tools = [
        final.gzip
        final.findutils
      ];
      run = ''
        while IFS= read -r -d "" p; do
          ${final.gzip}/bin/gzip -n -9 "$p"
        done < <(${final.findutils}/bin/find "$out/share/man" -type f ! -name '*.gz' -print0)
        while IFS= read -r -d "" p; do
          target=$(readlink "$p"); rm "$p"; ln -s "$target.gz" "$p.gz"
        done < <(${final.findutils}/bin/find "$out/share/man" -type l ! -name '*.gz' -print0)
      '';
    }
    (outputs.strip {
      elfKinds = [ "runtime" ];
      python = final.python;
      binutils = final.binutils;
      paths = [
        "bin"
        "lib"
      ];
    })
    (outputs.stripArchives {
      python = final.python;
      binutils = final.binutils;
      paths = [ "lib" ];
    })
    ((import ./rpaths.nix { inherit lib; }) {
      elfKinds = [ "runtime" ];
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      selfLibraryDirectory = true;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [
        "bin"
        "lib"
      ];
    })
    (outputs.development {
      python = final.python;
      libraries = [ ];
    })
    ((import ./check-paths.nix { inherit lib; }) {
      elfKinds = [ "runtime" ];
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      paths = [
        "bin"
        "lib"
      ];
    })
  ];
  tvp.features = final.features;
  meta = {
    homepage = "https://invisible-island.net/ncurses/";
    description = "Free software emulation of curses";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
