# Ncurses 5.8–5.9: pkg-config directory comes from the environment.
{
  tvp,
  lib,
  base,
  src,
  version,
  perl,
  doCheck ? true,
  patches ? [ ],
  hardeningDisable ? [ "format" ],
  cStandard ? "gnu89",
  cxxStandard ? "gnu++98",
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
    perl
    doCheck
    patches
    hardeningDisable
    cStandard
    cxxStandard
    ;
  inherit (tools) bash coreutils;
  buildFeatures = {
    cStandard = final.cStandard;
    cxxStandard = final.cxxStandard;
  };
  installedInterface = {
    finalizationContracts = false;
    modernInterfaces = false;
    widec = true;
    cxx = true;
    constUserData = true;
    pkgConfig = true;
    libName = "ncursesw";
    shared = true;
    static = true;
  };
  features = final.buildFeatures // final.installedInterface;
  configureFlags = [
    "--mandir=${placeholder "out"}/share/man"
    (if final.features.shared then "--with-shared" else "--without-shared")
    (if final.features.static then "--with-normal" else "--without-normal")
    (if final.features.widec then "--enable-widec" else "--disable-widec")
    (if final.features.cxx then "--with-cxx-binding" else "--without-cxx-binding")
    "--enable-pc-files"
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
    (command "patch.sources" ''
      for file in ${lib.escapeShellArgs (map (p: "${p}") final.patches)}; do
        ${tools.patch}/bin/patch -p1 < "$file"
      done
    '')
    (command "prepare" ''
      ${tools.sed}/bin/sed -i 's/preprocessor="$1 /preprocessor="$1 -P /' ncurses/base/MKlib_gen.sh
      ${tools.python}/bin/python3 -B ${./terminal-production-source.py} ${tools.bash}/bin/bash ${final.perl}/bin/perl '["configure", "config.guess", "config.sub", "install-sh", "misc", "progs", "include", "ncurses", "c++", "man"]'
    '')
    (command "configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash FORCE_UNSAFE_CONFIGURE=1
      export CFLAGS="''${CFLAGS:--O2} -std=${final.cStandard}"
      ${lib.optionalString (
        final.cxxStandard != null
      ) ''export CXXFLAGS="''${CXXFLAGS:--O2} -std=${final.cxxStandard}"''}
      export PKG_CONFIG_LIBDIR="$out/lib/pkgconfig"
      mkdir -p "$PKG_CONFIG_LIBDIR"
      # Keep the original test Makefile for the isolated upstream consumer.
      ./configure --prefix="$out" ${lib.escapeShellArgs final.configureFlags} --without-debug
    '')
    # Configure emits headers.sh with a literal /bin/sh interpreter.
    (steps.shebangs {
      name = "ncurses.install-helpers";
      python = tools.python;
      paths = [ "headers.sh" ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${tools.bash}/bin/bash";
    })
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
