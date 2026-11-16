# Ncurses 6.0–6.5 complete procedure; 6.2+ use the explicit default C++ dialect profile.
{
  tvp,
  lib,
  base,
  src,
  version,
  perl,
  doCheck ? true,
  cStandard ? "gnu17",
  cxxStandard ? "gnu++14",
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  checkpoint = "nix-support/ncurses-build-tree";
  command =
    name:
    steps.command {
      environment = final.environment;
    } "ncurses.${name}";
in
{
  pname = "ncurses";
  inherit
    base
    src
    version
    perl
    doCheck
    cStandard
    cxxStandard
    ;
  inherit (tools) bash coreutils;
  buildFeatures = {
    cStandard = final.cStandard;
    cxxStandard = final.cxxStandard;
  };
  installedInterface = {
    widec = true;
    cxx = true;
    pkgConfig = true;
    libName = "ncursesw";
    shared = true;
    static = true;
  };
  features = final.buildFeatures // final.installedInterface;
  configureFlags = [
    (if final.features.shared then "--with-shared" else "--without-shared")
    (if final.features.static then "--with-normal" else "--without-normal")
    (if final.features.widec then "--enable-widec" else "--disable-widec")
    (if final.features.cxx then "--with-cxx-binding" else "--without-cxx-binding")
    (if final.features.pkgConfig then "--enable-pc-files" else "--disable-pc-files")
  ];
  environment = {
    tools = [
      tools.gnumake
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
      tools.pkg-config
    ];
    libraries = [ ];
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
  runtime.libraries = [ ];
  development.includeDirectories = [
    "include/ncursesw"
    "include"
  ];
  productionPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = tools.gnutar;
      gzip = tools.gzip;
      findutils = tools.findutils;
      compression = "gzip";
    })
    (command "prepare" ''
      ${tools.python}/bin/python3 -B ${./terminal-production-source.py} ${tools.bash}/bin/bash ${final.perl}/bin/perl '["configure", "config.guess", "config.sub", "install-sh", "misc", "progs", "include", "ncurses", "c++", "man"]'
    '')
    (command "configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash FORCE_UNSAFE_CONFIGURE=1
      export CFLAGS="''${CFLAGS:--O2} -std=${final.cStandard}"
      ${lib.optionalString (
        final.cxxStandard != null
      ) ''export CXXFLAGS="''${CXXFLAGS:--O2} -std=${final.cxxStandard}"''}
      mkdir -p "$out/lib/pkgconfig"
      ./configure --prefix="$out" ${lib.escapeShellArgs final.configureFlags} --without-debug --with-pkg-config-libdir="$out/lib/pkgconfig" --with-pkg-config=${tools.pkg-config}/bin/pkg-config
    '')
    (command "production-targets" ''
      ${tools.python}/bin/python3 -B ${./production-make.py}
    '')
    (command "build" ''${tools.gnumake}/bin/make -f Makefile.production -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'')
    # Upstream supplies interactive test programs; installed C/C++/database
    # consumers are exercised by the ordinary suite instead of a make check target.
    (command "install" ''
      ${tools.gnumake}/bin/make -f Makefile.production -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash install
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
      name = "ncurses.restore-build-tree";
      checkpoint = "${artifact}/${checkpoint}";
    })
  ];
  upstreamCheck =
    (command "check" ''${tools.gnumake}/bin/make -C test -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'')
    // {
      enabled = final.doCheck;
    };
  plan = final.productionPlan ++ [
    (steps.split "ncurses.finalize")
    (outputs.copyArtifacts { })
    {
      name = "ncurses.drop-build-tree";
      tools = [ tools.coreutils ];
      run = ''${tools.coreutils}/bin/rm -rf -- "$out/${checkpoint}"'';
    }
    {
      name = "ncurses.relocate";
      tools = [
        tools.python
        tools.binutils
        tools.patchelf
      ];
      run = ''${tools.python}/bin/python3 -B ${./ordinary/output.py} "$out" "$TVP_ARTIFACT_ROOT" ${tools.patchelf}/bin/patchelf ${
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
            requiredFiles = [ "lib/libncursesw.a" ];
            requiredRegular = [ "lib/libncursesw.a" ];
          }
        )
      }'';
    }
    {
      name = "ncurses.manuals";
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
      paths = [
        "bin"
        "lib"
      ];
    })
    (outputs.stripArchives {
      python = tools.python;
      binutils = tools.binutils;
      paths = [ "lib" ];
    })
    ((import ./ordinary/rpaths.nix { inherit lib; }) {
      elfKinds = [ "runtime" ];
      python = tools.python;
      binutils = tools.binutils;
      patchelf = tools.patchelf;
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
      python = tools.python;
      libraries = [ ];
    })
    (outputs.checkLoaderPaths {
      elfKinds = [ "runtime" ];
      python = tools.python;
      binutils = tools.binutils;
      patchelf = tools.patchelf;
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
