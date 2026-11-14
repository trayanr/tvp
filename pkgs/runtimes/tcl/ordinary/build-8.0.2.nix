# Tcl 8.0.2–8.5.19: no external zlib, no bundled extensions or packages
# target. Keep the historical default configure/install interfaces and C dialect.
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
  gzip,
  findutils,
  sed,
  grep,
  gawk,
  diffutils,
  python,
  binutils,
  patchelf,
  cStandard ? null,
  reportedVersion ? version,
  patches ? [ ],
  patch,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "tcl.${name}";
      cwd = "source/unix";
      inherit run;
    };
  make = ''${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "tcl";
  inherit
    base
    src
    version
    bash
    coreutils
    patches
    patch
    cStandard
    reportedVersion
    ;
  tools = {
    inherit
      pkgConfig
      gnumake
      gnutar
      gzip
      findutils
      sed
      grep
      gawk
      diffutils
      python
      binutils
      patchelf
      ;
  };
  artifactName = "${final.pname}-${final.version}";
  dependencyProviders = final.tools // {
    bash = final.bash;
    coreutils = final.coreutils;
    patch = final.patch;
  };
  environment = {
    tools = [
      final.tools.pkgConfig
      final.tools.gnumake
      final.tools.sed
      final.tools.grep
      final.tools.gawk
      final.tools.diffutils
      final.tools.findutils
      final.tools.python
    ];
    libraries = [ ];
  };
  runtime = {
    shell = final.bash;
    loader = "${final.base.compiler.libc}/lib/ld-linux-x86-64.so.2";
    libraries = [ ];
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.tools.gnutar;
      inherit (final.tools) gzip findutils;
      compression = "gzip";
    })
    {
      name = "tcl.patch";
      enabled = final.patches != [ ];
      cwd = "source";
      tools = [ final.patch ];
      run = lib.concatMapStringsSep "\n" (
        p: "${final.patch}/bin/patch --batch --fuzz=0 -p1 < ${p}"
      ) final.patches;
    }
    (steps.prepareAutotools {
      name = "tcl.prepare";
      bash = final.bash;
      inherit (final.tools) python;
      base = final.base;
      cwd = "source/unix";
    })
    (steps.shebangs {
      name = "tcl.package-shells";
      inherit (final.tools) python;
      paths = [
        "unix"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      export CFLAGS="-g -O2 ${lib.optionalString (final.cStandard != null) "-std=${final.cStandard}"}"
      ${final.bash}/bin/bash ./configure --prefix="$out"
    '')
    (command "build" ''${make}'')
    (command "install" ''
      export LD_LIBRARY_PATH="$PWD"
      ${make} install
      mkdir -p "$out/nix-support"
      ln -s "$(basename "$out"/bin/tclsh*)" "$out/bin/tclsh"
      chmod -R u+w "$out"
    '')
    (steps.split "tcl.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "tcl.relocate-prefix";
      tools = [ final.tools.python ];
      run = ''${final.tools.python}/bin/python3 -B ${../relocate.py} "$out"'';
    }
    (outputs.shebangs {
      inherit (final.tools) python;
      paths = [
        "bin"
        "lib"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.runtime.shell}/bin/bash";
    })
    (outputs.interpreters {
      inherit (final.tools) python binutils patchelf;
      paths = [ "bin" ];
      loader = final.runtime.loader;
    })
    (outputs.strip {
      inherit (final.tools) python binutils;
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [ "runtime" ];
    })
    (outputs.stripArchives {
      inherit (final.tools) python binutils;
      paths = [ "lib" ];
    })
    (outputs.rpaths {
      inherit (final.tools) python binutils patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [ "runtime" ];
    })
    (outputs.development {
      inherit (final.tools) python;
      libraries = [ ];
    })
    (outputs.checkPaths {
      inherit (final.tools) python binutils patchelf;
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [ "runtime" ];
    })
  ];
  tvp.reportedVersion = final.reportedVersion;
  tvp.features = {

    are = lib.versionAtLeast final.version "8.1";
    pkgConfig = lib.versionAtLeast final.version "8.5.16";
    zipfsImage = false;
    bundledPackages = false;
  };
  meta = {
    description = "Tool Command Language interpreter";
    homepage = "https://www.tcl-lang.org/";
    license = lib.licenses.tcltk;
    platforms = [ "x86_64-linux" ];
  };
}
