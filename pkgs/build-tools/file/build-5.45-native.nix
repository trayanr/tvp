# File 5.45–5.47 retain libmagic, four codec providers and the compiled default magic database.
# Complete ordinary procedure; latest and frozen construction remain independently selected.
{
  tvp,
  lib,
  base,
  src,
  version,
  zlib,
  xz,
  bzip2,
  zstd,
  binutils,
  configureFlags ? [ ],
  doCheck ? true,
}:

final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs;
  baseTools = context.tools;
  inherit (final)
    bash
    coreutils
    gnumake
    gnutar
    gzip
    sed
    grep
    gawk
    diffutils
    findutils
    python
    patchelf
    ;
  productionMake =
    target:
    lib.concatMapStringsSep "\n"
      (
        directory:
        let
          noTestRecursion = lib.optionalString (directory == ".") " SUBDIRS=.";
        in
        ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" -C ${lib.escapeShellArg directory} SHELL=${final.bash}/bin/bash ${target}${noTestRecursion}''
      )
      [
        "src"
        "magic"
        "doc"
        "python"
        "."
      ];
  command = steps.command {
    environment = final.environment;
  };
  make = ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
  elfPaths = [
    "bin/file"
    "lib"
  ];
in
{
  pname = "file";
  inherit doCheck;
  bash = baseTools.bash;
  coreutils = baseTools.coreutils;
  gnumake = baseTools.gnumake;
  gnutar = baseTools.gnutar;
  gzip = baseTools.gzip;
  sed = baseTools.sed;
  grep = baseTools.grep;
  gawk = baseTools.gawk;
  diffutils = baseTools.diffutils;
  findutils = baseTools.findutils;
  python = baseTools.python;
  patchelf = baseTools.patchelf;

  inherit
    base
    src
    version
    ;
  inherit
    zlib
    xz
    bzip2
    zstd
    binutils
    configureFlags
    ;
  dependencyProviders = {
    zlib = final.zlib;
    xz = final.xz;
    bzip2 = final.bzip2;
    zstd = final.zstd;
    binutils = final.binutils;
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
    libraries = [
      final.zlib
      final.xz
      final.bzip2
      final.zstd
    ];
  };
  runtime.libraries = [
    final.zlib
    final.xz
    final.bzip2
    final.zstd
  ];
  upstreamCheck =
    (
      (final.base.environment final.environment)
      // {
        name = "file.upstream";
        run = ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" check'';
      }
    )
    // {
      enabled = final.doCheck;
    };
  originalPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.gnutar;
      gzip = final.gzip;
      findutils = final.findutils;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "file.prepare";
      bash = final.bash;
      python = final.python;
      base = final.base;
    })
    (command "file.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" --enable-zlib --enable-bzlib --enable-xzlib --enable-zstdlib --enable-static --enable-shared ${lib.escapeShellArgs final.configureFlags}
    '')
    (command "file.build" (productionMake "all"))
    (command "file.install" ''
      ${productionMake "install"}
      test -s "$out/share/misc/magic.mgc"
      test -s "$out/include/magic.h"
      test -s "$out/lib/pkgconfig/libmagic.pc"
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "file.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "file.relocate";
      tools = [ final.python ];
      run = ''
        ${final.python}/bin/python3 -B ${../../../lib/relocate.py} "$out" "$TVP_ARTIFACT_ROOT" "${final.patchelf}/bin/patchelf"
      '';
    }
    (outputs.strip {
      python = final.python;
      binutils = final.binutils;
      paths = elfPaths;
    })
    (outputs.stripArchives {
      python = final.python;
      binutils = final.binutils;
      paths = [ "lib/libmagic.a" ];
    })
    (outputs.rpaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      base = final.base;
      paths = elfPaths;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
    })
    # Keep static libmagic's .la and private pkg-config compression requirements.
    (outputs.development {
      python = final.python;
      libraries = [
        final.zlib
        final.xz
        final.bzip2
        final.zstd
      ];
    })
    (outputs.checkSymlinks {
      python = final.python;
      paths = [
        "lib/libmagic.so"
        "lib/libmagic.so.1"
      ];
    })
    (outputs.checkPaths {
      python = final.python;
      binutils = final.binutils;
      patchelf = final.patchelf;
      paths = elfPaths;
    })
  ];
  meta = {
    description = "File type identification utility and libmagic";
    license = lib.licenses.bsd2;
    platforms = lib.platforms.unix;
    mainProgram = "file";
  };
  upstreamPlan = artifact: [
    {
      name = "file.restore-build-tree";
      tools = [ baseTools.python ];
      run = ''
        ${baseTools.python}/bin/python3 -B ${../../../lib/restore-checkpoint.py} ${artifact}/nix-support/file-build-tree "$TVP_SOURCE_ROOT"
        printf '%s\n' ${artifact} > "$TVP_SOURCE_ROOT/production-artifact"
      '';
    }
  ];
  plan =
    let
      parts = steps.partition final.originalPlan;
      production = parts.first;
    in
    production
    ++ [
      {
        name = "file.save-build-tree";
        tools = [
          baseTools.python
          final.coreutils
        ];
        run = ''
          ${baseTools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/nix-support/file-build-tree"
        '';
      }
    ]
    ++ (lib.optional parts.split (steps.split "file.finalize"))
    ++ [
      (builtins.head parts.second)
      {
        name = "file.drop-build-tree";
        tools = [ final.coreutils ];
        run = ''${final.coreutils}/bin/rm -rf -- "$out/nix-support/file-build-tree"'';
      }
    ]
    ++ builtins.tail parts.second;

}
