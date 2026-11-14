# 0.28: independent public source-GNU procedure, with all generated upstream groups.
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
  python,
  binutils,
  patchelf,
  gmp,
  findutils,
  sed,
  grep,
  gawk,
  diffutils,
  gzip,
  doCheck ? true,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "isl.${name}";
      cwd = "source";
      run = run;
    };
in
{
  pname = "isl";
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
      xz
      python
      binutils
      patchelf
      findutils
      sed
      grep
      gawk
      diffutils
      gzip
      ;
  };
  libraries = {
    inherit gmp;
  };
  configureFlags = [
    "--with-gmp=system"
    "--with-gmp-prefix=${final.libraries.gmp}"
    "--enable-shared"
    "--enable-static"
  ];
  development.libraries = [ final.libraries.gmp ];
  dependencyProviders = final.tools // final.libraries;
  environment = {
    tools = [
      final.tools.gnumake
      final.tools.findutils
      final.tools.sed
      final.tools.grep
      final.tools.gawk
      final.tools.diffutils
      final.tools.gnutar
      final.tools.gzip
    ];
    libraries = [ final.libraries.gmp ];
  };
  runtime.libraries = [ final.libraries.gmp ];
  artifactPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      inherit (final.tools) xz findutils;
      tar = final.tools.gnutar;
    })
    (command "validate-source" ''
      ${final.tools.python}/bin/python3 -B ${./validate-source.py} "$PWD" '{}' validate-source
    '')
    (steps.prepareAutotools {
      name = "isl.prepare";
      bash = final.bash;
      inherit (final.tools) python;
      base = final.base;
    })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "build" ''${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'')
    (command "install" ''
      ${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash install
      mkdir -p "$out/share/licenses/isl"
      cp LICENSE "$out/share/licenses/isl/"
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
  ];
  inherit doCheck;
  upstreamPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      inherit (final.tools) xz findutils;
      tar = final.tools.gnutar;
    })
    (command "validate-source" ''
      ${final.tools.python}/bin/python3 -B ${./validate-source.py} "$PWD" '{}' validate-source
    '')
    (steps.prepareAutotools {
      name = "isl.prepare";
      bash = final.bash;
      inherit (final.tools) python;
      base = final.base;
    })
    (command "configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "build" ''${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'')
  ];
  upstreamCheck = (
    (command "check" ''${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash check || { status=$?; cat test-suite.log >&2; exit "$status"; }'')
    // {
      enabled = final.doCheck;
    }
  );
  plan = steps.sequence (
    final.artifactPlan
    ++ [
      (steps.split "isl.finalize")
      (outputs.copyArtifacts { coreutils = final.coreutils; })
      (outputs.relocateText {
        python = final.tools.python;
        paths = [
          "lib/pkgconfig"
          "lib/libisl.la"
        ];
      })
      (outputs.libtool {
        inherit (final.tools) python;
        paths = [ "lib/libisl.la" ];
      })
      (outputs.strip {
        inherit (final.tools) python binutils;
        paths = [ "lib" ];
      })
      (outputs.stripArchives {
        inherit (final.tools) python binutils;
        paths = [ "lib" ];
      })
      (outputs.rpaths {
        inherit (final.tools) python binutils patchelf;
        base = final.base;
        libraries = final.runtime.libraries;
        paths = [ "lib" ];
      })
      (outputs.development {
        inherit (final.tools) python;
        libraries = final.development.libraries;
      })
      (outputs.checkPaths {
        inherit (final.tools) python binutils patchelf;
        paths = [ "lib" ];
      })
    ]
  );
  tvp.features = {
    doCheck = final.doCheck;
    shared = true;
    static = true;
    cxx = true;
  };
  meta = {
    description = "Integer sets and relations library for polyhedral compilation";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
