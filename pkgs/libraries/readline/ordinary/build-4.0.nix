# Readline 4.0–4.2a: explicit shared build/install and refreshed platform scripts.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  pkgConfig,
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
  ncurses,
  perl,
  doCheck ? true,
  automake,
  cStandard ? "gnu89",
  pkgConfigModules ? [ ],
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "readline.${name}";
      cwd = "source";
      inherit run;
    };
in
{
  pname = "readline";
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
    automake
    cStandard
    pkgConfigModules
    ncurses
    ;
  features = {
    pkgConfigModules = final.pkgConfigModules;
    finalizationContracts = false;
    completionMatches = false;
    shared = true;
    history = true;
    static = true;
  };
  # Shared/static targets are explicit make targets in this generation.
  configureFlags = [ ];
  environment = {
    tools = [
      final.pkgConfig
      final.gnumake
      final.sed
      final.grep
      final.gawk
      final.diffutils
      final.findutils
    ];
    libraries = [ final.ncurses ];
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
  runtime.libraries = [ final.ncurses ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.gnutar;
      gzip = final.gzip;
      findutils = final.findutils;
      compression = "gzip";
    })
    (command "prepare" ''
      cp ${final.automake}/share/automake-${final.automake.version}/config.{guess,sub} support/
      chmod +w support/config.guess support/config.sub
      ${final.python}/bin/python3 -B ${../../ncurses/ordinary/source.py} ${final.bash}/bin/bash ${final.perl}/bin/perl '["configure", "support"]'
    '')
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash FORCE_UNSAFE_CONFIGURE=1
      export CFLAGS="-O2 -std=${final.cStandard}"
      ./configure --prefix="$out" --mandir="$out/share/man" --infodir="$out/share/info" --with-curses ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "build" ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash SHLIB_LIBS=-lncursesw static ${lib.optionalString final.features.shared "shared"}'')
    (command "install" ''
      ${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash SHLIB_LIBS=-lncursesw install ${lib.optionalString final.features.shared "install-shared"}
      ${lib.optionalString final.features.shared ''test -s "$out/lib/libreadline.so"; test -s "$out/lib/libhistory.so"''}
      for module in ${lib.escapeShellArgs final.pkgConfigModules}; do test -s "$out/lib/pkgconfig/$module.pc"; done
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "readline.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "readline.relocate";
      tools = [
        final.python
        final.binutils
        final.patchelf
      ];
      run = ''${final.python}/bin/python3 -B ${../../ncurses/ordinary/output.py} "$out" "$TVP_ARTIFACT_ROOT" ${final.patchelf}/bin/patchelf ${
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
            pkgConfigRequires = lib.optionalAttrs (builtins.elem "readline" final.pkgConfigModules) {
              "lib/pkgconfig/readline.pc" = {
                before = "ncurses";
                after = "ncursesw";
              };
            };
            requiredFiles = [ "lib/libreadline.a" ] ++ lib.optional final.features.history "lib/libhistory.a";
            requiredRegular = [
              "lib/libreadline.a"
            ] ++ map (m: "lib/pkgconfig/${m}.pc") final.pkgConfigModules;
          }
        )
      }'';
    }
    {
      name = "readline.manuals";
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
      paths = [ "lib" ];
    })
    ((import ../../ncurses/ordinary/rpaths.nix { inherit lib; }) {
      elfKinds = [ "runtime" ];
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [ "lib" ];
    })
    (outputs.development {
      python = final.python;
      libraries = [ ];
    })
    ((import ../../ncurses/ordinary/check-paths.nix { inherit lib; }) {
      elfKinds = [ "runtime" ];
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      paths = [ "lib" ];
    })
  ];
  tvp.features = final.features;
  meta = {
    homepage = "https://tiswww.case.edu/php/chet/readline/rltop.html";
    description = "Library for interactive line editing";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
  };
}
