# Ncurses 4.2–5.7: historical wide names, no pkg-config, optional old C++ bindings.
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
  gnu-config,
  cxxBinding ? true,
  cStandard ? "gnu89",
  cxxStandard ? "gnu++98",
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  checkpoint = "nix-support/ncurses-build-tree";
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
    perl
    doCheck
    patches
    hardeningDisable
    gnu-config
    cxxBinding
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
    cxx = final.cxxBinding && lib.versionAtLeast final.version "5.0";
    constUserData = final.cxxBinding && lib.versionAtLeast final.version "5.3";
    pkgConfig = false;
    libName = if lib.versionAtLeast final.version "5.1" then "ncursesw" else "ncurses";
    shared = true;
    static = true;
  };
  features = final.buildFeatures // final.installedInterface;
  configureFlags = [
    "--mandir=${placeholder "out"}/share/man"
    (if final.features.shared then "--with-shared" else "--without-shared")
    (if final.features.static then "--with-normal" else "--without-normal")
    (if final.features.widec then "--enable-widec" else "--disable-widec")
  ] ++ lib.optional (!final.cxxBinding) "--without-cxx-binding";

  environment = {
    tools = [
      tools.gnumake
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
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
    "include/${final.features.libName}"
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
      # 4.2's executable clear.sh is a one-line shell body without a header.
      # Adapt this known historical frontend before the confined shell mutator.
      ${tools.python}/bin/python3 -B - <<'PYTHON'
      from pathlib import Path
      p = Path('progs/clear.sh')
      data = p.read_bytes()
      if not data.startswith(b'#!'):
          assert data == b'exec tput clear\n', 'unexpected historical clear frontend'
          p.write_bytes(b'#!/bin/sh\n' + data)
      PYTHON
      cp ${final.gnu-config}/config.guess ${final.gnu-config}/config.sub .
      chmod +w config.guess config.sub
      ${tools.sed}/bin/sed -i 's/1\*|2\./1.*|2./g' configure
      for generator in ncurses/MKlib_gen.sh ncurses/base/MKlib_gen.sh; do
        if test -f "$generator"; then
          ${tools.sed}/bin/sed -i 's/preprocessor="$1 /preprocessor="$1 -P /' "$generator"
        fi
      done
      ${tools.sed}/bin/sed -i 's|SRC_SUBDIRS="$SRC_SUBDIRS misc test"|SRC_SUBDIRS="$SRC_SUBDIRS misc"|' configure
      helpers=(configure config.guess config.sub install-sh misc progs include ncurses c++ man)
      if test -f mkinstalldirs; then helpers+=(mkinstalldirs); fi
      selections=$(${tools.python}/bin/python3 -c 'import json, sys; print(json.dumps(sys.argv[1:]))' "''${helpers[@]}")
      ${tools.python}/bin/python3 -B ${./terminal-production-source.py} ${tools.bash}/bin/bash ${final.perl}/bin/perl "$selections"
    '')
    (command "configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash FORCE_UNSAFE_CONFIGURE=1
      export CFLAGS="''${CFLAGS:--O2} -std=${final.cStandard}"
      ${lib.optionalString (
        final.cxxStandard != null
      ) ''export CXXFLAGS="''${CXXFLAGS:--O2} -std=${final.cxxStandard}"''}
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
    (command "build" ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'')
    # Upstream supplies interactive test programs; installed C/C++/database
    # consumers are exercised by the ordinary suite instead of a make check target.
    (command "install" ''
      ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash install
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
            requiredFiles = [ "lib/lib${final.features.libName}.a" ];
            requiredRegular = [ "lib/lib${final.features.libName}.a" ];
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
    ((import ./ordinary/check-paths.nix { inherit lib; }) {
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
