# gdbm 1.8.0: complete production procedure; upstream checks consume its saved checkpoint.
{
  tvp,
  lib,
  base,
  src,
  version,
  file,
  doCheck ? true,
  cStandard ? "gnu89",
  commonSymbols ? false,
  patches ? [ ],
  sourceLayout ? {
    selections = [
      "configure"
      "config.sub"
      "config.guess"
      "install-sh"
      "mkinstalldirs"
      "ltmain.sh"
      "ltconfig"
    ];
    shellFragments = {
      "ltmain.sh" = [ "# ltmain.sh - Provide generalized library-building support services." ];
    };
    libtoolAnchors = {
      "ltmain.sh" = 0;
    };
    edits = [
      {
        path = "Makefile.in";
        before = " -o $(BINOWN) -g $(BINGRP)";
        after = "";
        count = 5;
      }
    ];
  },
  roundtrip ? true,
  finalizerControls ? true,
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  environment = final.base.environment final.environment;
  command =
    name: run:
    environment
    // {
      name = "gdbm.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash CFLAGS="-O2${
    lib.optionalString (final.cStandard != null) " -std=${final.cStandard}"
  }${lib.optionalString final.commonSymbols " -fcommon"}"'';
  checkpoint = "nix-support/gdbm-build-tree";
in
{
  pname = "gdbm";
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    file
    doCheck
    cStandard
    commonSymbols
    patches
    sourceLayout
    roundtrip
    finalizerControls
    ;
  inherit (tools) bash coreutils;
  buildFeatures = {
    shared = true;
    static = true;
    compatLib = false;
  };
  installedInterface = {
    roundtrip = final.roundtrip;
    cli = false;
    finalizerControls = final.finalizerControls;
  };
  features = final.buildFeatures // final.installedInterface;
  configureFlags = [
    (if final.buildFeatures.shared then "--enable-shared" else "--disable-shared")
    (if final.buildFeatures.static then "--enable-static" else "--disable-static")
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
      final.file
    ];
    libraries = [ ];
  };
  runtime = {
    shell = tools.bash;
    tools = [
      tools.coreutils
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
    ];
    libraries = [ ];
    dlopenDirectories = [ ];
  };
  productionPlan = steps.sequence [

    (steps.unpack {
      src = final.src;
      tar = tools.gnutar;
      inherit (tools) gzip findutils;
      compression = "gzip";
    })
    (
      (command "prepare" ''
        ${tools.python}/bin/python3 -B ${../dbm-yaml-source.py} ${tools.bash}/bin/bash ${
          lib.escapeShellArg (
            builtins.toJSON (
              final.sourceLayout
              // {
                patches = map (p: "${p}") final.patches;
              }
            )
          )
        }
      '')
      // {
        tools = environment.tools ++ [ tools.python ];
      }
    )
    (command "configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash
      export CFLAGS="-O2${
        lib.optionalString (final.cStandard != null) " -std=${final.cStandard}"
      }${lib.optionalString final.commonSymbols " -fcommon"}"
      touch gdbm.info
      ./configure --host=${final.base.platform.config} --prefix="$out" ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "build" make)
    (command "install" ''
      mkdir -p "$out/lib" "$out/include" "$out/share/man/man3" "$out/share/info"
      ${make} install install-compat prefix="$out" libdir="$out/lib" includedir="$out/include" man3dir="$out/share/man/man3" infodir="$out/share/info"
      mkdir -p "$out/include/gdbm"
      ln -s ../dbm.h ../gdbm.h ../ndbm.h "$out/include/gdbm/"
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
  ];
  upstreamUnavailable = "These pre-Automake releases have no check target; installed store/ndbm controls remain registered, including known failures.";
  plan = final.productionPlan ++ [
    (steps.split "gdbm.finalize")
    (outputs.copyArtifacts { })
    {
      name = "gdbm.relocate";
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
            requiredFiles = [
              "lib/libgdbm.a"
              "lib/libgdbm.la"
              "include/gdbm.h"
              "include/dbm.h"
              "include/ndbm.h"
            ];
            libtoolData = [ "lib/libgdbm.la" ];
            requiredRegular = [
              "lib/libgdbm.a"
              "lib/libgdbm.la"
              "include/gdbm.h"
              "include/dbm.h"
              "include/ndbm.h"
            ];
          }
        )
      }'';
    }
    {
      name = "gdbm.manuals";
      tools = [
        tools.gzip
        tools.findutils
        final.file
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
      inherit (tools) python binutils;
      paths = [ "lib" ];
      elfKinds = [ "runtime" ];
    })
    (outputs.stripArchives {
      inherit (tools) python binutils;
      paths = [ "lib/libgdbm.a" ];
    })
    (outputs.libtool {
      inherit (tools) python;
      paths = [ "lib/libgdbm.la" ];
    })
    ((import ./ordinary/rpaths.nix { inherit lib; }) {
      inherit (tools) python binutils patchelf;
      inherit (final) base;
      paths = [ "lib" ];
      elfKinds = [ "runtime" ];
      selfLibraryDirectory = true;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
    })
    (outputs.development {
      inherit (tools) python;
      libraries = [ ];
    })
    ((import ./ordinary/check-paths.nix { inherit lib; }) {
      inherit (tools) python binutils patchelf;
      paths = [ "lib" ];
      elfKinds = [ "runtime" ];
    })
  ];
  tvp.features = final.features // {
    doCheck = final.doCheck;
  };
  meta = {
    description = "GNU dbm key/value database library";
    homepage = "https://www.gnu.org/software/gdbm/";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
  };
}
