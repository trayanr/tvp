# Readline 8.3: independent current procedure; upstream check is validation-only.
{
  tvp,
  lib,
  base,
  src,
  version,
  ncurses,
  perl,
  doCheck ? true,
  cStandard ? null,
  installedInterface ? {
    static = false;
    propagateNcurses = false;
  },
  pkgConfigModules ? [
    "readline"
    "history"
  ],
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
    cStandard
    pkgConfigModules
    ncurses
    ;
  inherit (tools) bash coreutils;
  buildFeatures = { };
  installedInterface = {
    pkgConfigModules = final.pkgConfigModules;
    shared = true;
    history = true;
    static = installedInterface.static;
    propagateNcurses = installedInterface.propagateNcurses;
    upstreamCheck = true;
  };
  features = final.buildFeatures // final.installedInterface;
  configureFlags = [
    (if final.features.shared then "--enable-shared" else "--disable-shared")
    (if final.features.static then "--enable-static" else "--disable-static")
  ];
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
    (command "prepare" ''
      ${tools.python}/bin/python3 -B ${../ncurses/terminal-production-source.py} ${tools.bash}/bin/bash ${final.perl}/bin/perl '["configure", "support", "shlib"]'
    '')
    (command "configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash FORCE_UNSAFE_CONFIGURE=1
      ${lib.optionalString (final.cStandard != null) ''export CFLAGS="-O2 -std=${final.cStandard}"''}
      ./configure --prefix="$out" --with-curses ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "build" ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash SHLIB_LIBS=-lncursesw'')
    (command "install" ''
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash SHLIB_LIBS=-lncursesw install
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
  upstreamPlan = artifact: [
    (steps.restoreCheckpoint {
      name = "readline.restore-build-tree";
      checkpoint = "${artifact}/${checkpoint}";
    })
  ];
  upstreamCheck =
    (command "check" ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash SHLIB_LIBS=-lncursesw check'')
    // {
      enabled = final.doCheck;
    };
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
            # 8.3 maps -lncursesw to ncursesw itself; older releases emit ncurses.
            requiredFiles =
              lib.optional final.features.static "lib/libreadline.a"
              ++ map (m: "lib/pkgconfig/${m}.pc") final.pkgConfigModules;
            requiredRegular =
              lib.optional final.features.static "lib/libreadline.a"
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
      libraries = lib.optional final.installedInterface.propagateNcurses final.ncurses;
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
