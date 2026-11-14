# Complete native source-GNU procedure for 5.2.37 only; retained construction generations remain independent.
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
  python,
  binutils,
  patchelf,
  sed,
  grep,
  gawk,
  diffutils,
  findutils,
  gzip,
  ncurses,
  cStandard ? "gnu17",
  configureFlags ? [ ],
  doCheck ? true,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "bash.${name}";
      cwd = "source";
      inherit run;
    };
  make = ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
in
{
  pname = "bash";
  # Equal-width compiled-prefix ABI; the artifact remains a distinct producer.
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    bash
    coreutils
    gnumake
    gnutar
    python
    binutils
    patchelf
    sed
    grep
    gawk
    diffutils
    findutils
    gzip
    ncurses
    cStandard
    configureFlags
    doCheck
    ;
  environment = {
    tools = [
      final.gnumake
      final.sed
      final.grep
      final.gawk
      final.diffutils
      final.findutils
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
      python = final.python;
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
      tar = final.gnutar;
      findutils = final.findutils;
      gzip = final.gzip;
      compression = "gzip";
    })
    (steps.shebangs {
      name = "bash.source-shells";
      python = final.python;
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
      export CFLAGS="''${CFLAGS:--g -O2} -std=${final.cStandard}" LIBS=-lncursesw
      ${final.bash}/bin/bash ./configure --prefix="$out" --disable-static --with-curses ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "build" make)
    # Bounded shipped smoke tests: their diagnostics are retained, not a claim
    # of the entire Bash upstream conformance suite.
    (command "install" ''
      ${make} install
      ln -s bash "$out/bin/sh"
    '')
    (steps.split "bash.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "bash.relocate";
      tools = [ final.python ];
      run = ''${final.python}/bin/python3 -B ${../../../build-tools/owned-split-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        lib.escapeShellArg (
          builtins.toJSON {
            text = [ ];
            slots = [ ];
            fixed = [ ];
          }
        )
      } ${../../../../lib/installed-tree.py}'';
    }
    {
      name = "bash.self-helpers";
      tools = [ final.python ];
      run = ''
        ${final.python}/bin/python3 -B ${./self-helpers.py} "$out" ${../../../../lib/native-output} ${final.coreutils}/bin/install
      '';
    }
    (outputs.shebangs {
      python = final.python;
      paths = [ "bin/bashbug" ];
      names = [
        "sh"
        "bash"
      ];
      selfInterpreter = "bin/bash";
    })
    (outputs.strip {
      python = final.python;
      binutils = final.binutils;
      paths = [
        "bin"
        "lib"
      ];
    })
    (outputs.stripArchives {
      python = final.python;
      binutils = final.binutils;
      paths = [ "lib" ];
    })
    (outputs.rpaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      base = final.base;
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
        final.python
        final.patchelf
      ];
      run = ''
        ${final.python}/bin/python3 -B ${./self-rpaths.py} "$out" ${../../../../lib/native-output} ${final.binutils}/bin/readelf ${final.patchelf}/bin/patchelf
      '';
    }
    (outputs.development {
      python = final.python;
      libraries = final.development.libraries or [ ];
    })
    (outputs.checkPaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
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
