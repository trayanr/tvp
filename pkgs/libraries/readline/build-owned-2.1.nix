# Readline 2.1–2.2.1: static-only, preserving the historical archive/header profile.
{
  tvp,
  lib,
  base,
  src,
  version,
  ncurses,
  perl,
  gnu-config ? null,
  doCheck ? true,
  patches ? [ ],
  commonSymbols ? false,
  cStandard ? "gnu89",
  pkgConfigModules ? [ ],
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  checkpoint = "nix-support/readline-build-tree";
  command =
    name:
    steps.command {
      environment = final.environment;
    } "readline.${name}";
in
{
  pname = "readline";
  inherit
    base
    src
    version
    perl
    doCheck
    patches
    commonSymbols
    cStandard
    pkgConfigModules
    ncurses
    gnu-config
    ;
  inherit (tools) bash coreutils;
  buildFeatures = { };
  installedInterface = {
    pkgConfigModules = final.pkgConfigModules;
    finalizationContracts = false;
    completionMatches = false;
    shared = false;
    history = lib.versionAtLeast final.version "2.2";
    static = true;
  };
  features = final.buildFeatures // final.installedInterface;
  configureFlags = [ ];
  environment = {
    tools = [
      tools.pkg-config
      tools.gnumake
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
    ];
    libraries = [ final.ncurses ];
  };
  runtime.shell = tools.bash;
  runtime.tools = [
    tools.coreutils
    tools.sed
    tools.grep
    tools.gawk
    tools.diffutils
    tools.findutils
  ];
  runtime.libraries = [ final.ncurses ];
  productionPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = tools.gnutar;
      gzip = tools.gzip;
      findutils = tools.findutils;
      compression = "gzip";
    })
    (command "patch.sources" ''
      for file in ${lib.escapeShellArgs (map (p: "${p}") final.patches)}; do
        ${tools.patch}/bin/patch -p1 < "$file"
      done
    '')
    (command "prepare" (
      lib.optionalString (final.gnu-config != null) ''
        cp ${final.gnu-config}/config.{guess,sub} support/
        chmod +w support/config.guess support/config.sub
      ''
      + ''
        ${tools.python}/bin/python3 -B ${../ncurses/terminal-production-source.py} ${tools.bash}/bin/bash ${final.perl}/bin/perl '["configure", "support"]'
      ''
    ))
    (command "configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash FORCE_UNSAFE_CONFIGURE=1
      export CFLAGS="-O2 -std=${final.cStandard}${lib.optionalString final.commonSymbols " -fcommon"} -I${lib.getDev final.ncurses}/include/ncursesw"
      ./configure --prefix="$out" --mandir="$out/share/man" --infodir="$out/share/info" --with-curses ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "build" ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash SHLIB_LIBS=-lncursesw libreadline.a ${lib.optionalString final.features.history "libhistory.a"}'')
    (command "install" ''
      mkdir -p "$out/include"
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash SHLIB_LIBS=-lncursesw incdir="$out/include" install
      test -s "$out/lib/libreadline.a"
      ${lib.optionalString final.features.history ''test -s "$out/lib/libhistory.a"''}
      for module in ${lib.escapeShellArgs final.pkgConfigModules}; do test -s "$out/lib/pkgconfig/$module.pc"; done
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (
      (command "save-build-tree" ''
        ${tools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/${checkpoint}"
      '')
      // {
        tools = final.environment.tools ++ [ tools.python ];
      }
    )
  ];
  # This historical procedure has no authored automatic upstream protocol.
  plan = final.productionPlan ++ [
    (steps.split "readline.finalize")
    (outputs.copyArtifacts { })
    {
      name = "readline.drop-build-tree";
      tools = [ tools.coreutils ];
      run = ''${tools.coreutils}/bin/rm -rf -- "$out/${checkpoint}"'';
    }
    {
      name = "readline.relocate";
      tools = [
        tools.python
        tools.binutils
        tools.patchelf
      ];
      run = ''${tools.python}/bin/python3 -B ${../ncurses/ordinary/output.py} "$out" "$TVP_ARTIFACT_ROOT" ${tools.patchelf}/bin/patchelf ${
        lib.escapeShellArg (
          builtins.toJSON {
            readelf = "${tools.binutils}/bin/readelf";
            shell = "${final.runtime.shell}/bin/bash";
            buildShell = "${tools.bash}/bin/bash";
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
            ]
            ++ map (m: "lib/pkgconfig/${m}.pc") final.pkgConfigModules;
          }
        )
      }'';
    }
    {
      name = "readline.manuals";
      tools = [
        tools.gzip
        tools.findutils
      ];
      run = ''
        while IFS= read -r -d "" p; do
          ${tools.gzip}/bin/gzip -n -9 "$p"
        done < <(${tools.findutils}/bin/find "$out/share/man" -type f ! -name '*.gz' -print0)
        while IFS= read -r -d "" p; do
          target=$(readlink "$p"); rm "$p"; ln -s "$target.gz" "$p.gz"
        done < <(${tools.findutils}/bin/find "$out/share/man" -type l ! -name '*.gz' -print0)
      '';
    }
    (outputs.strip {
      elfKinds = [ "runtime" ];
      python = tools.python;
      binutils = tools.binutils;
      paths = [ "lib" ];
    })
    ((import ../ncurses/ordinary/rpaths.nix { inherit lib; }) {
      elfKinds = [ "runtime" ];
      python = tools.python;
      binutils = tools.binutils;
      patchelf = tools.patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [ "lib" ];
    })
    (outputs.development {
      python = tools.python;
      libraries = [ ];
    })
    (outputs.checkLoaderPaths {
      elfKinds = [ "runtime" ];
      python = tools.python;
      binutils = tools.binutils;
      patchelf = tools.patchelf;
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
