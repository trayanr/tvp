# Ordinary native 8.6.18 only: the 8.x Tcl extension ABI and full bundled Itcl/SQLite/TDBC/Thread installation are required by ordinary consumers.
# Earlier releases and source-bootstrap generations retain independent procedures.
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
  testPatches ? [ ],
  patch,
  doCheck ? true,
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
      patch
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
  };
  testSource = final.src;
  inherit testPatches;
  testShell = final.bash;
  testPython = final.tools.python;
  testPrepare = ../tests/prepare-native.py;
  testRunner = ../tests/run-native.py;
  upstreamExpected = "upstream-ok";
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
      export LDFLAGS="''${LDFLAGS:-} -Wl,--no-as-needed -lgcc_s -Wl,--as-needed"
      ./configure --prefix="$out" --enable-threads --enable-shared --with-zlib=${final.libraries.zlib}
    '')
    (command "build" ''${make} binaries libraries doc'')
    (command "packages" ''
      export LD_LIBRARY_PATH="$PWD"
      ${make} packages TCLSH_NATIVE="$PWD/tclsh"
    '')
    (command "install" ''
      export LD_LIBRARY_PATH="$PWD"
      ${make} install install-private-headers TCLSH_NATIVE="$PWD/tclsh"
      mkdir -p "$out/nix-support"
      ln -s tclsh8.6 "$out/bin/tclsh"
      chmod -R u+w "$out"
    '')
    (command "receipt" ''
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
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
  tvp.features = {
    inherit doCheck;
    are = true;
    pkgConfig = true;
    zipfsImage = false;
    bundledPackages = true;
    threads = true;
  };
  meta = {
    description = "Tool Command Language interpreter";
    homepage = "https://www.tcl-lang.org/";
    license = lib.licenses.tcltk;
    platforms = [ "x86_64-linux" ];
  };
}
