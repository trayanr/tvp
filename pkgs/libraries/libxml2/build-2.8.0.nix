# 2.8.0 complete production profile; U consumes its private compiled checkpoint.
{
  tvp,
  lib,
  base,
  src,
  version,
  zlib,
  liblzma,
  cStandard ? "gnu89",
  cFlags ? [ ],
  installedInterface ? {
    sonameMajor = "2";
  },
  doCheck ? true,
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
      name = "libxml2.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'';
  checkpoint = "nix-support/libxml2-build-tree";
  elfPaths = [
    "bin"
    "lib"
  ];
in
{
  pname = "libxml2";
  inherit
    base
    src
    version
    zlib
    liblzma
    cStandard
    cFlags
    installedInterface
    doCheck
    ;
  inherit (tools) bash coreutils;
  artifactName = "${final.pname}-${final.version}";
  configureFlags = [
    "--without-python"
    "--with-zlib=${lib.getDev final.zlib}"
    "--with-lzma=${lib.getDev final.liblzma}"
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
    libraries = [
      final.zlib
      final.liblzma
    ];
    overrides.values.CFLAGS = "-O2 -std=${final.cStandard} ${lib.concatStringsSep " " final.cFlags}";
  };
  runtime = {
    libraries = [
      final.zlib
      final.liblzma
    ];
    shell = tools.bash;
  };
  productionPlan = steps.sequence [
    (steps.unpack { src = final.src; })
    (
      (command "prepare" ''
        ${tools.python}/bin/python3 -B ${./ordinary/prepare.py} ${tools.bash}/bin/bash
      '')
      // {
        tools = environment.tools ++ [ tools.python ];
      }
    )
    (command "configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash
      export lt_cv_deplibs_check_method=pass_all
      ./configure --prefix="$out" ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "build" ''${make} libxml2.la xmllint xmlcatalog'')
    (command "install" ''
      # The root install target in 2.10 also generates testapi.c. Enter the
      # generated recursive installer directly; retain all installed directories.
      # Noninstalled programs/libraries are test/example targets, restored for U.
      ${make} noinst_PROGRAMS= noinst_LTLIBRARIES= install-recursive
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (
      (command "save-build-tree" ''
        ${tools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/${checkpoint}"
      '')
      // {
        tools = environment.tools ++ [ tools.python ];
      }
    )
  ];
  upstreamPlan = artifact: [
    {
      name = "libxml2.restore-build-tree";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${./tests/restore.py} ${artifact}/${checkpoint} "$TVP_SOURCE_ROOT"'';
    }
    {
      name = "libxml2.bind-configured-header";
      tools = [ tools.coreutils ];
      run = ''
        mkdir -p "$out/include/libxml2/libxml" "$out/nix-support"
        cp -- ${artifact}/include/libxml2/libxml/xmlversion.h "$out/include/libxml2/libxml/xmlversion.h"
      '';
    }
  ];
  upstreamCheck =
    (command "check" ''
      ${tools.python}/bin/python3 -B ${./ordinary/capture.py} "$out/nix-support/upstream-raw" \
        ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash \
        ${lib.escapeShellArg "CHECKER=${tools.python}/bin/python3 -B ${./ordinary/capture-command.py}"} check
      cat "$out/nix-support/upstream-raw/stdout"
      # The shared raw wrapper records the real make outcome as well. The
      # original signed exit remains byte-for-byte in the capture's exit.json.
      ${tools.python}/bin/python3 -c 'import json,sys; n=json.load(open(sys.argv[1]))["exit"]; sys.exit(n if n >= 0 else 128 - n)' "$out/nix-support/upstream-raw/exit.json"
    '')
    // {
      enabled = final.doCheck;
      tools = environment.tools ++ [ tools.python ];
    };
  upstreamProfile = "source-bound-capture";
  plan = final.productionPlan ++ [
    (steps.split "libxml2.finalize")
    (outputs.copyArtifacts { })
    {
      name = "libxml2.drop-build-tree";
      tools = [ tools.coreutils ];
      run = ''rm -rf -- "$out/${checkpoint}"'';
    }
    {
      name = "libxml2.relocate";
      tools = [
        tools.python
        tools.binutils
        tools.patchelf
      ];
      run = ''
        mkdir finalize-helper
        cp ${./ordinary/finalize.py} finalize-helper/finalize.py
        cp ${./ordinary/elf.py} finalize-helper/elf.py
        ${tools.python}/bin/python3 -B finalize-helper/finalize.py "$out" "$TVP_ARTIFACT_ROOT" ${tools.binutils}/bin/readelf ${tools.patchelf}/bin/patchelf
      '';
    }
    (outputs.shebangs {
      paths = [ "bin/xml2-config" ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.runtime.shell}/bin/bash";
    })
    (outputs.strip {
      paths = elfPaths;
      flags = [
        "-S"
        "-p"
      ];
      elfKinds = [ "runtime" ];
    })
    (outputs.stripArchives { paths = [ "lib/libxml2.a" ]; })
    (outputs.rpaths {
      base = final.base;
      paths = elfPaths;
      libraries = final.runtime.libraries;
      elfKinds = [ "runtime" ];
    })
    (outputs.development { libraries = final.runtime.libraries; })

    (outputs.checkPaths {
      paths = elfPaths;
      elfKinds = [ "runtime" ];
    })
  ];
  tvp.features = {
    inherit (final) doCheck;
    libraryAbi = final.installedInterface.sonameMajor;
    xpath = true;
    lzma = true;
    shared = true;
    static = true;
    python = false;
    icu = false;
    iconv = true;
    http = true;
  };
  meta = {
    description = "XML parsing library for C";
    homepage = "https://gitlab.gnome.org/GNOME/libxml2";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
