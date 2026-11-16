# Complete Bash5.2.37 procedure; private checked-recipe U remains separate.
{
  tvp,
  lib,
  base,
  src,
  version,
  ncurses,
  buildFeatures ? { },
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
    } "bash.${name}";
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "bash";
  # Equal-width compiled-prefix ABI; the artifact remains a distinct producer.
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    ncurses
    doCheck
    ;
  inherit (tools) bash coreutils;
  buildFeatures = {
    cStandard = "gnu17";
    configureFlags = [ ];
  } // buildFeatures;
  environment = {
    tools = [
      tools.gnumake
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
    ];
    libraries = [ final.ncurses ];
  };
  runtime = {
    libraries = final.environment.libraries;
    dlopenDirectories = [ ];
  };
  upstreamPreparation = [
    (steps.shebangs {
      name = "bash.source-shells";
      paths = [ "tests" ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
  ];
  upstreamCheck = {
    enabled = final.doCheck;
    before = "bash.install";
    command = (
      (command "check" ''
        ./bash --noprofile --norc -c 'set -eu; test "$((21 * 2))" = 42; declare -A a=([tvp]=ok); test "''${a[tvp]}" = ok'
        ${make} -C examples/loadables all
      '')
      // {
        enabled = final.doCheck;
      }
    );
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (steps.shebangs {
      name = "bash.source-shells";
      paths = [
        "configure"
        "support"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      export CFLAGS="''${CFLAGS:--g -O2} -std=${final.buildFeatures.cStandard}" LIBS=-lncursesw
      ${final.bash}/bin/bash ./configure --prefix="$out" --disable-static --with-curses ${lib.escapeShellArgs final.buildFeatures.configureFlags}
    '')
    (command "build" make)
    # Bounded shipped smoke tests: their diagnostics are retained, not a claim
    # of the entire Bash upstream conformance suite.
    (command "install" ''
      ${make} install
      ln -s bash "$out/bin/sh"
    '')
    (steps.split "bash.finalize")
    (outputs.copyArtifacts { })
    {
      name = "bash.relocate";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../../build-tools/owned-split-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        lib.escapeShellArg (
          builtins.toJSON {
            text = [ ];
            slots = [ ];
            fixed = [ ];
          }
        )
      } ${../../../lib/installed-tree.py}'';
    }
    {
      name = "bash.self-helpers";
      tools = [ tools.python ];
      run = ''
        ${tools.python}/bin/python3 -B ${./native/self-helpers.py} "$out" ${../../../lib/native-output} ${final.coreutils}/bin/install
      '';
    }
    (outputs.shebangs {
      paths = [ "bin/bashbug" ];
      names = [
        "sh"
        "bash"
      ];
      selfInterpreter = "bin/bash";
    })
    (outputs.strip {
      paths = [
        "bin"
        "lib"
      ];
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
    })
    {
      name = "output.self-rpaths";
      tools = [
        tools.python
        tools.patchelf
      ];
      run = ''
        ${tools.python}/bin/python3 -B ${./native/self-rpaths.py} "$out" ${../../../lib/native-output} ${tools.binutils}/bin/readelf ${tools.patchelf}/bin/patchelf
      '';
    }
    (outputs.development {
      libraries = final.development.libraries or [ ];
    })
    (outputs.checkPaths {
      paths = [
        "bin"
        "lib"
      ];
    })
  ];
  tvp.features = {
    readline = "bundled";
    curses = "wide";
    loadables = true;
  };
  meta = {
    description = "GNU Bourne Again Shell";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
  };
}
