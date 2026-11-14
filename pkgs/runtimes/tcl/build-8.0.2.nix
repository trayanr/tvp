# Complete Tcl8.0.2 procedure; construction callers are explicitly retained.
{
  tvp,
  lib,
  base,
  src,
  version,
  buildFeatures ? { },
  installedInterface ? { },
  patches ? [ ],
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "tcl.${name}";
      cwd = "source/unix";
      inherit run;
    };
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
  buildFeatures = {
    cStandard = "gnu89";
  } // buildFeatures;
  installedInterface = {
    reportedVersion = final.version;
    pkgConfigVersion = final.version;
  } // installedInterface;
  artifactName = "${final.pname}-${final.version}";
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
      compression = "gzip";
    })
    {
      name = "tcl.patch";
      enabled = final.patches != [ ];
      cwd = "source";
      tools = [ tools.patch ];
      run = lib.concatMapStringsSep "\n" (
        p: "${tools.patch}/bin/patch --batch --fuzz=0 -p1 < ${p}"
      ) final.patches;
    }
    (steps.prepareAutotools {
      name = "tcl.prepare";
      cwd = "source/unix";
    })
    (steps.shebangs {
      name = "tcl.package-shells";
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
      export CFLAGS="-g -O2 ${
        lib.optionalString (final.buildFeatures.cStandard != null) "-std=${final.buildFeatures.cStandard}"
      }"
      ${final.bash}/bin/bash ./configure --prefix="$out"
    '')
    (command "build" "${make}")
    (command "install" ''
      export LD_LIBRARY_PATH="$PWD"
      ${make} install
      mkdir -p "$out/nix-support"
      ln -s "$(basename "$out"/bin/tclsh*)" "$out/bin/tclsh"
      chmod -R u+w "$out"
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
      libraries = [ ];
    })
    (outputs.checkPaths {
      paths = [
        "bin"
        "lib"
      ];
      elfKinds = [ "runtime" ];
    })
  ];
  tvp.reportedVersion = final.installedInterface.reportedVersion;
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
