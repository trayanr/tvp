# Complete Tcl8.6.18 procedure; construction callers are explicitly retained.
{
  tvp,
  lib,
  base,
  src,
  version,
  zlib,
  libgcc,
  patches ? [ ],
  testPatches ? [ ],
  doCheck ? true,
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  command =
    name:
    steps.command {
      environment = final.environment;
      cwd = "source/unix";
    } "tcl.${name}";
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "tcl";
  inherit
    base
    src
    version
    patches
    ;
  inherit (tools) bash coreutils;
  inherit testPatches doCheck;
  libraries = {
    inherit zlib libgcc;
  };
  artifactName = "${final.pname}-${final.version}";
  dependencyProviders = {
    inherit (final.runtime) zlib libgcc;
  };
  testSource = final.src;
  testShell = final.bash;
  testPython = tools.python;
  testPrepare = ./tests/prepare-native.py;
  testRunner = ./tests/run-native.py;
  upstreamExpected = "upstream-ok";
  environment = {
    tools = [
      tools.pkg-config
      tools.gnumake
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
      tools.python
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
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "tcl.prepare";
      cwd = "source/unix";
    })
    (steps.shebangs {
      name = "tcl.package-shells";
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
    (command "build" "${make} binaries libraries doc")
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
    (outputs.copyArtifacts { })
    {
      name = "tcl.relocate-prefix";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${./relocate.py} "$out"'';
    }
    (outputs.shebangs {
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
      paths = [ "bin" ];
      loader = final.runtime.loader;
    })
    (outputs.strip {
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [ "runtime" ];
    })
    (outputs.stripArchives {
      paths = [ "lib" ];
    })
    (outputs.rpaths {
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [ "runtime" ];
    })
    (outputs.development {
      libraries = [ final.runtime.zlib ];
    })
    (outputs.checkPaths {
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
