# Gperf 3.1 through 3.2.1: shipped generated files, full upstream checks and explicit C++ runtime.
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
  gzip,
  findutils,
  sed,
  grep,
  gawk,
  diffutils,
  python,
  binutils,
  patchelf,
  libstdcxx,
  configureFlags ? [ ],
}:
let
  inherit (tvp.builder) steps outputs;
in
final:
let
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      inherit name run;
      cwd = "source";
    };
  make = ''${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
  elfPaths = [ "bin" ];
in
{
  pname = "gperf";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  tools = {
    inherit
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
    inherit libstdcxx;
  };
  configureFlags = configureFlags;
  dependencyProviders = final.tools // {
    libstdcxx = builtins.head final.runtime.libraries;
  };
  environment = {
    tools = [
      final.tools.gnumake
      final.tools.sed
      final.tools.grep
      final.tools.gawk
      final.tools.diffutils
      final.tools.findutils

    ];
    libraries = [ ];
  };
  runtime.libraries = [ final.libraries.libstdcxx ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.tools.gnutar;
      gzip = final.tools.gzip;
      findutils = final.tools.findutils;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "gperf.prepare";
      bash = final.bash;
      python = final.tools.python;
      base = final.base;
    })
    (command "gperf.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out"  ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "gperf.build" make)
    (command "gperf.check" ''
      ${make} check
    '')
    (command "gperf.install" ''
      ${make} install
      :
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')

    (steps.split "gperf.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    (outputs.strip {
      python = final.tools.python;
      binutils = final.tools.binutils;
      paths = elfPaths;
    })

    (outputs.rpaths {
      python = final.tools.python;
      binutils = final.tools.binutils;
      patchelf = final.tools.patchelf;
      base = final.base;
      paths = elfPaths;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
    })
    (outputs.development {
      python = final.tools.python;
      libraries = [ ];
    })

    (outputs.checkPaths {
      python = final.tools.python;
      binutils = final.tools.binutils;
      patchelf = final.tools.patchelf;
      paths = elfPaths;
    })
  ];
  meta = {
    homepage = "https://www.gnu.org/software/gperf/";
    description = "GNU perfect hash function generator";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "gperf";
  };
}
