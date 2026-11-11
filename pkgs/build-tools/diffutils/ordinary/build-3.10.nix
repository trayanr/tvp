# Diffutils 3.10–3.11 share lib/config.h and configured PR_PROGRAM pagination.
# Independent ordinary procedure; latest and retained construction stay separate.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  buildCoreutils,
  gnumake,
  gnutar,
  xz,
  gzip,
  python,
  perl,
  binutils,
  patchelf,
  sed,
  grep,
  gawk,
  diffutils,
  findutils,
  coreutils,
  doCheck ? true,
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
  rpaths =
    {
      python,
      binutils,
      patchelf,
      base,
      paths,
      libraries,
      dlopenDirectories ? [ ],
      elfKinds ? null,
    }:
    {
      name = "output.rpaths";
      tools = [
        python
        binutils
        patchelf
      ];
      run = ''${python}/bin/python3 -B ${../../../libraries/ordinary-compression-rpaths.py} "$out" ${
        lib.escapeShellArg (
          builtins.toJSON {
            inherit paths dlopenDirectories elfKinds;
            libraries = lib.concatMap (
              p: (p.development or { }).libraryDirectories or [ "${lib.getLib p}/lib" ]
            ) libraries;
            baseDirectories = base.runtimeDirectories;
            readelf = "${binutils}/bin/readelf";
            patchelf = "${patchelf}/bin/patchelf";
          }
        )
      } ${../../../../lib/native-output}'';
    };

in
{
  pname = "diffutils";
  inherit
    base
    src
    version
    bash
    ;
  coreutils = final.buildCoreutils;
  helperCoreutils = coreutils;
  inherit
    buildCoreutils
    gnumake
    gnutar
    xz
    gzip
    python
    perl
    binutils
    patchelf
    sed
    grep
    gawk
    diffutils
    findutils
    doCheck
    ;
  configureFlags = [ ];
  stripFlags = [
    "-S"
    "-p"
  ];
  dependencyProviders = {
    bash = final.bash;
    buildCoreutils = final.buildCoreutils;
    gnumake = final.gnumake;
    gnutar = final.gnutar;
    xz = final.xz;
    gzip = final.gzip;
    python = final.python;
    perl = final.perl;
    binutils = final.binutils;
    patchelf = final.patchelf;
    sed = final.sed;
    grep = final.grep;
    gawk = final.gawk;
    diffutils = final.diffutils;
    findutils = final.findutils;
    coreutils = final.helperCoreutils;
  };
  environment = {
    tools = [
      final.gnumake
      final.sed
      final.grep
      final.gawk
      final.diffutils
      final.findutils
      final.perl
    ];
    libraries = [ ];
  };
  runtime.shell = final.bash;
  runtime.tools = [
    final.coreutils
    final.sed
    final.grep
    final.gawk
    final.diffutils
    final.findutils
  ];
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      xz = final.xz;
      findutils = final.findutils;
      tar = final.gnutar;
    })
    (command "diffutils.prepare" ''
      ${final.python}/bin/python3 -B ${../../ordinary-text-source.py} ${final.bash}/bin/bash ${final.perl}/bin/perl '${
        builtins.toJSON [
          "build-aux"
          "tests"
        ]
      }'
    '')
    (command "diffutils.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash FORCE_UNSAFE_CONFIGURE=1
      export PR_PROGRAM=${final.helperCoreutils}/bin/pr
      ./configure --prefix="$out" ${lib.escapeShellArgs final.configureFlags} --enable-nls
      ${final.grep}/bin/grep '^#define ENABLE_NLS 1' lib/config.h
    '')
    (command "diffutils.build" ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
    (
      (command "diffutils.check" ''
        ${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" check
      '')
      // {
        enabled = final.doCheck;
      }
    )
    (command "diffutils.install" ''
      ${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
      cp lib/config.h "$out/nix-support/config.h"
      ${final.grep}/bin/grep -Ex 'gt_cv_func_gnugettext[0-9]+_libc=yes' config.log > "$out/nix-support/gettext-libc"
    '')
    (steps.split "diffutils.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "diffutils.relocate";
      tools = [
        final.python
        final.binutils
        final.patchelf
      ];
      run = ''${final.python}/bin/python3 -B ${../../ordinary-text-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${final.patchelf}/bin/patchelf ${
        lib.escapeShellArg (
          builtins.toJSON {
            readelf = "${final.binutils}/bin/readelf";
            shell = "${final.runtime.shell}/bin/bash";
            buildShell = "${final.bash}/bin/bash";
            paths = map (p: "${p}/bin") final.runtime.tools;
          }
        )
      }'';
    }
    {
      name = "output.manuals";
      tools = [
        final.gzip
        final.findutils
      ];
      run = ''
        while IFS= read -r -d "" manual; do
          ${final.gzip}/bin/gzip -n -9 "$manual"
        done < <(${final.findutils}/bin/find "$out/share/man" -type f ! -name '*.gz' -print0)
        while IFS= read -r -d "" manual; do
          target=$(readlink "$manual")
          rm "$manual"
          ln -s "$target.gz" "$manual.gz"
        done < <(${final.findutils}/bin/find "$out/share/man" -type l ! -name '*.gz' -print0)
      '';
    }
    (outputs.strip {
      flags = final.stripFlags;
      python = final.python;
      binutils = final.binutils;
      paths = [ "bin" ];
      elfKinds = [ "runtime" ];
    })
    (rpaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
      paths = [ "bin" ];
      elfKinds = [ "runtime" ];
    })
    ((import ../../ordinary-text-check-paths.nix { inherit lib; }) {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      paths = [ "bin" ];
      elfKinds = [ "runtime" ];
    })
  ];
  meta = {
    description = "GNU file comparison utilities";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
  };
}
