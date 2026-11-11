# 2.7.4–2.7.8: no LZMA option; GNU89 weak pthread declarations.
# Complete independent source procedure; retained stdenv recipes are unchanged.
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
  xz,
  gnused,
  gnugrep,
  gawk,
  diffutils,
  findutils,
  pkg-config,
  zlib,
  python,
  binutils,
  patchelf,
  libraryAbi,
  cStandard ? "gnu17",
  cFlags ? [ ],
  doCheck ? true,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  environment = final.base.environment final.environment;
  command =
    name: run:
    environment
    // {
      name = "libxml2.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
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
    bash
    coreutils
    libraryAbi
    cStandard
    cFlags
    doCheck
    ;
  artifactName = "${final.pname}-${final.version}";
  tools = {
    inherit
      gnumake
      gnutar
      xz
      gnused
      gnugrep
      gawk
      diffutils
      findutils
      pkg-config
      python
      binutils
      patchelf
      ;
  };
  libraries = {
    inherit zlib;
  };
  dependencyProviders = final.tools // final.libraries;
  preparationHelper = ./prepare.py;
  captureHelper = ./capture.py;
  commandCaptureHelper = ./capture-command.py;
  classifier = ./classify.py;
  finalizationHelper = ./finalize.py;
  elfHelper = ./elf.py;
  configureFlags = [
    "--without-python"
    "--with-zlib=${lib.getDev final.libraries.zlib}"
  ];
  stripFlags = [
    "-S"
    "-p"
  ];
  environment = {
    tools = with final.tools; [
      gnumake
      gnused
      gnugrep
      gawk
      diffutils
      findutils
      pkg-config
    ];
    libraries = builtins.attrValues final.libraries;
    overrides.values.CFLAGS = "-O2 -std=${final.cStandard} ${lib.concatStringsSep " " final.cFlags}";
  };
  runtime = {
    libraries = builtins.attrValues final.libraries;
    shell = final.bash;
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      xz = final.tools.xz;
      findutils = final.tools.findutils;
      tar = final.tools.gnutar;
    })
    (
      (command "prepare" ''
        ${final.tools.python}/bin/python3 -B ${final.preparationHelper} ${final.bash}/bin/bash
      '')
      // {
        tools = (environment.tools or [ ]) ++ [ final.tools.python ];
      }
    )
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      export lt_cv_deplibs_check_method=pass_all
      ./configure --prefix="$out" ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "build" make)
    (
      (command "capture-upstream" ''
        ${final.tools.python}/bin/python3 -B ${final.captureHelper} upstream-raw ${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash ${lib.escapeShellArg "CHECKER=${final.tools.python}/bin/python3 -B ${final.commandCaptureHelper}"} check
      '')
      // {
        tools = (environment.tools or [ ]) ++ [ final.tools.python ];
        enabled = final.doCheck;
      }
    )
    (command "install" ''
      ${make} install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
      ${lib.optionalString final.doCheck ''cp -a upstream-raw "$out/nix-support/upstream-raw"''}
    '')
    (steps.split "libxml2.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "libxml2.classify-upstream";
      tools = [
        final.tools.python
        final.coreutils
      ];
      run = ''
        ${lib.optionalString final.doCheck ''
          ${final.tools.python}/bin/python3 -B ${final.classifier} "$out/nix-support/upstream-raw" ${lib.escapeShellArg final.version}
          ${final.coreutils}/bin/rm -r "$out/nix-support/upstream-raw"
        ''}
      '';
    }
    {
      name = "libxml2.relocate";
      tools = with final.tools; [
        python
        binutils
        patchelf
      ];
      run = ''
        mkdir finalize-helper
        cp ${final.finalizationHelper} finalize-helper/finalize.py
        cp ${final.elfHelper} finalize-helper/elf.py
        ${final.tools.python}/bin/python3 -B finalize-helper/finalize.py "$out" "$TVP_ARTIFACT_ROOT" ${final.tools.binutils}/bin/readelf ${final.tools.patchelf}/bin/patchelf
      '';
    }
    (outputs.shebangs {
      python = final.tools.python;
      paths = [ "bin/xml2-config" ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.runtime.shell}/bin/bash";
    })
    (outputs.strip {
      python = final.tools.python;
      binutils = final.tools.binutils;
      paths = elfPaths;
      flags = final.stripFlags;
      elfKinds = [ "runtime" ];
    })
    (outputs.stripArchives {
      python = final.tools.python;
      binutils = final.tools.binutils;
      paths = [ "lib/libxml2.a" ];
    })
    (outputs.rpaths {
      python = final.tools.python;
      binutils = final.tools.binutils;
      patchelf = final.tools.patchelf;
      base = final.base;
      paths = elfPaths;
      libraries = final.runtime.libraries;
      elfKinds = [ "runtime" ];
    })
    (outputs.development {
      python = final.tools.python;
      libraries = final.runtime.libraries;
    })
    (outputs.checkPaths {
      python = final.tools.python;
      binutils = final.tools.binutils;
      patchelf = final.tools.patchelf;
      paths = elfPaths;
      elfKinds = [ "runtime" ];
    })
  ];
  tvp.features = {
    inherit (final) doCheck libraryAbi;
    xpath = lib.versionAtLeast final.version "2.7.7";
    lzma = false;
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
    platforms = lib.platforms.unix;
  };
}
