# Ordinary 5.48 only: owned commands and explicit compression/output policy.
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
          localTarget =
            if directory == "." then (if target == "all" then "all-am" else "install-am") else target;
        in
        ''${final.gnumake}/bin/make -j"$NIX_BUILD_CORES" -C ${lib.escapeShellArg directory} SHELL=${final.bash}/bin/bash ${localTarget}''
      )
      [
        "src"
        "magic"
        "doc"
        "python"
        "."
      ];
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      inherit name run;
      cwd = "source";
    };
  make = ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash'';
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

  # Equal-width compiled-prefix ABI; the artifact remains a distinct producer.
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    ;
  environment = {
    tools = [
      gnumake
      sed
      grep
      gawk
      diffutils
      findutils
    ];
    libraries = [
      zlib
      xz
      bzip2
      zstd
    ];
  };
  runtime.libraries = [
    zlib
    xz
    bzip2
    zstd
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
      tar = gnutar;
      inherit gzip findutils;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "file.prepare";
      bash = final.bash;
      inherit python;
      base = final.base;
    })
    (command "file.configure" ''
      export CONFIG_SHELL=${final.bash}/bin/bash
      ./configure --prefix="$out" --enable-zlib --enable-bzlib --enable-xzlib --enable-zstdlib --enable-static --enable-shared ${lib.escapeShellArgs configureFlags}
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
      tools = [ python ];
      run = ''${python}/bin/python3 -B ${../owned-split-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${
        lib.escapeShellArg (
          builtins.toJSON {
            text = [ ];
            slots = [ ];
            fixed = [ ];
          }
        )
      } ${../../../lib/installed-tree.py}'';
    }
    (outputs.strip {
      inherit python binutils;
      paths = elfPaths;
    })
    (outputs.stripArchives {
      inherit python binutils;
      paths = [ "lib/libmagic.a" ];
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      paths = elfPaths;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
    })
    # Keep static libmagic's .la and private pkg-config compression requirements.
    (outputs.development {
      inherit python;
      libraries = [
        zlib
        xz
        bzip2
        zstd
      ];
    })
    (outputs.checkSymlinks {
      inherit python;
      paths = [
        "lib/libmagic.so"
        "lib/libmagic.so.1"
      ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = elfPaths;
    })
  ];
  meta = {
    description = "File type identification utility and libmagic";
    license = lib.licenses.bsd2;
    platforms = [ "x86_64-linux" ];
    mainProgram = "file";
  };
  upstreamPlan = artifact: [
    {
      name = "file.restore-build-tree";
      tools = [ baseTools.python ];
      run = ''
        ${baseTools.python}/bin/python3 -B ${../utilities-restore.py} ${artifact}/nix-support/file-build-tree "$TVP_SOURCE_ROOT"
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
