# Ncurses 6.2–6.3 use normal C++ defaults; configure requires pkg-config on PATH.
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
  inherit
    base
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
    ;
  features = {
    cStandard = final.cStandard;
    cxxStandard = final.cxxStandard;
    widec = true;
    cxx = true;
    pkgConfig = true;
    libName = "ncursesw";
    shared = true;
    static = true;
  };
  configureFlags = [
    (if final.features.shared then "--with-shared" else "--without-shared")
    (if final.features.static then "--with-normal" else "--without-normal")
    (if final.features.widec then "--enable-widec" else "--disable-widec")
    (if final.features.cxx then "--with-cxx-binding" else "--without-cxx-binding")
    (if final.features.pkgConfig then "--enable-pc-files" else "--disable-pc-files")
  ];
  environment = {
    tools = [
      final.gnumake
      final.sed
      final.grep
      final.gawk
      final.diffutils
      final.findutils
      final.pkgConfig
    ];
    libraries = [ ];
  };
  cStandard = "gnu17";
  cxxStandard = null;
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
    "include/ncursesw"
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
    (command "prepare" ''
      ${final.python}/bin/python3 -B ${./source.py} ${final.bash}/bin/bash ${final.perl}/bin/perl '["configure", "config.guess", "config.sub", "install-sh", "misc", "progs", "include", "ncurses", "c++", "man"]'
    '')
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash FORCE_UNSAFE_CONFIGURE=1
      export CFLAGS="''${CFLAGS:--O2} -std=${final.cStandard}"
      ${lib.optionalString (
        final.cxxStandard != null
      ) ''export CXXFLAGS="''${CXXFLAGS:--O2} -std=${final.cxxStandard}"''}
      mkdir -p "$out/lib/pkgconfig"
      ./configure --prefix="$out" ${lib.escapeShellArgs final.configureFlags} --without-debug --with-pkg-config-libdir="$out/lib/pkgconfig" --with-pkg-config=${final.pkgConfig}/bin/pkg-config
    '')
    (command "build" ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'')
    (
      (command "check" ''
        # Upstream has no automatic check target; compile its complete test programs.
        ${final.gnumake}/bin/make -C test -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash
      '')
      // {
        enabled = final.doCheck;
      }
    )
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
            requiredFiles = [ "lib/libncursesw.a" ];
            requiredRegular = [ "lib/libncursesw.a" ];
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
