# Tcl 8.6.0–8.6.17 and 9.0.x: bundled extensions introduce the packages
# target and an explicit external zlib dependency. Retained construction is independent.
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
  zlib,
  libgcc,
  cStandard ? null,
  reportedVersion ? version,
  pkgConfigVersion ? version,
  linkUnwinder ? false,
  zipfsImage ? true,
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
    pkgConfigVersion
    linkUnwinder
    zipfsImage
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
  libraries = {
    inherit zlib libgcc;
  };
  artifactName = "${final.pname}-${final.version}";
  dependencyProviders = final.tools // {
    inherit (final.runtime) zlib libgcc;
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
    libraries = [
      final.libraries.zlib
      final.libraries.libgcc
    ];
  };
  runtime = {
    shell = final.bash;
    loader = "${final.base.compiler.libc}/lib/ld-linux-x86-64.so.2";
    inherit (final.libraries) zlib libgcc;
    libraries = [
      final.runtime.zlib
      final.runtime.libgcc
    ];
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
        "pkgs"
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
      ${lib.optionalString final.linkUnwinder ''export LDFLAGS="''${LDFLAGS:-} -Wl,--no-as-needed -lgcc_s -Wl,--as-needed"''}
      export CFLAGS="-g -O2 ${lib.optionalString (final.cStandard != null) "-std=${final.cStandard}"}"
      ${final.bash}/bin/bash ./configure --prefix="$out" --with-zlib=${final.libraries.zlib} ${
        lib.optionalString (!final.zipfsImage) "--disable-zipfs"
      }
    '')
    (command "build" ''${make} binaries libraries doc'')
    (command "packages" ''
      export LD_LIBRARY_PATH="$PWD"
      ${make} packages TCLSH_NATIVE="$PWD/tclsh"
    '')
    (command "install" ''
      export LD_LIBRARY_PATH="$PWD"
      ${make} install TCLSH_NATIVE="$PWD/tclsh"
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
      libraries = [ final.runtime.zlib ];
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
  tvp.pkgConfigVersion = final.pkgConfigVersion;
  tvp.features = {

    are = true;
    pkgConfig = true;
    zipfsImage = final.zipfsImage && lib.versionAtLeast final.version "9.0";
    bundledPackages = true;
  };
  meta = {
    description = "Tool Command Language interpreter";
    homepage = "https://www.tcl-lang.org/";
    license = lib.licenses.tcltk;
    platforms = [ "x86_64-linux" ];
  };
}
