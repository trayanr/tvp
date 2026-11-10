# Patch 2.8 uses the revised charset implementation; no 2.8.1 harness patch is applied.
# Complete ordinary procedure; latest and frozen construction remain independently selected.
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
  gzip,
  python,
  binutils,
  patchelf,
  sed,
  grep,
  gawk,
  diffutils,
  findutils,
  patch,
  patches ? [ ],
  doCheck ? true,
  configureFlags ? [ ],
  stripFlags ? [
    "-S"
    "-p"
  ],
}:
let
  inherit (tvp.builder) steps outputs;
in
final:
let
  environment = final.base.environment final.environment;
  command =
    name: run:
    environment
    // {
      inherit name run;
      cwd = "source";
    };
in
{
  pname = "patch";
  inherit
    base
    src
    version
    bash
    coreutils
    python
    patch
    gnumake
    gnutar
    gzip
    xz
    gawk
    diffutils
    findutils
    binutils
    patchelf
    sed
    grep
    doCheck
    configureFlags
    stripFlags
    patches
    ;
  dependencyProviders = {
    bash = final.bash;
    coreutils = final.coreutils;
    gnumake = final.gnumake;
    gnutar = final.gnutar;
    xz = final.xz;
    gzip = final.gzip;
    python = final.python;
    binutils = final.binutils;
    patchelf = final.patchelf;
    sed = final.sed;
    grep = final.grep;
    gawk = final.gawk;
    diffutils = final.diffutils;
    findutils = final.findutils;
    patch = final.patch;
  };
  environment = {
    tools = [
      final.gnumake
      final.sed
      final.grep
      final.gawk
      final.diffutils
      final.findutils
    ];
    libraries = [ ];
  };
  runtime = {
    libraries = [ ];
    dlopenDirectories = [ ];
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      xz = final.xz;
      tar = final.gnutar;
      findutils = final.findutils;
    })
    (command "patch.sources" ''
      for file in ${lib.escapeShellArgs (map (p: "${p}") final.patches)}; do
        ${final.patch}/bin/patch -p1 < "$file"
      done
    '')
    (steps.shebangs {
      name = "patch.source-shells";
      python = final.python;
      paths = [
        "configure"
        "tests"
        "build-aux"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${final.bash}/bin/bash";
    })
    (command "patch.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      ${final.bash}/bin/bash ./configure --prefix="$out" --disable-dependency-tracking \
        ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "patch.build" ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'')
    (
      (command "patch.check" ''
        status=0
        ${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash check || status=$?
        if (( status )); then cat tests/test-suite.log >&2 || :; fi
        exit "$status"
      '')
      // {
        enabled = final.doCheck;
      }
    )
    (command "patch.install" ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash install'')
    (steps.split "patch.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "patch.relocate";
      tools = [ final.python ];
      run = ''
        ${final.python}/bin/python3 -B ${./relocate.py} "$out" "$TVP_ARTIFACT_ROOT" "${final.patchelf}/bin/patchelf"
      '';
    }
    {
      name = "output.manuals";
      tools = [ final.gzip ];
      run = ''
        ${final.gzip}/bin/gzip -n -9 "$out/share/man/man1/patch.1"
      '';
    }
    (outputs.strip {
      python = final.python;
      binutils = final.binutils;
      paths = [ "bin/patch" ];
      flags = final.stripFlags;
    })
    (outputs.rpaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      base = final.base;
      paths = [ "bin/patch" ];
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
    })
    (outputs.checkPaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      paths = [ "bin/patch" ];
    })
  ];
  meta = {
    description = "GNU patch application utility";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
    mainProgram = "patch";
  };
}
