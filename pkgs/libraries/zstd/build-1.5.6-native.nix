# Zstd 1.5.6: explicit Zlib/LZMA codec linkage, with LZ4 disabled.
# Independent ordinary procedure; compiler construction keeps its retained call.
{
  tvp,
  lib,
  base,
  src,
  version,
  binutils,
  zlib,
  xz,
  doCheck ? true,
}:

let
  upstreamTests = [
    "basic/help.sh"
    "basic/version.sh"
    "compression/basic.sh"
    "compression/gzip-compat.sh"
    "decompression/pass-through.sh"
  ];
  cwd = "source";

in
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
    gnused
    gnugrep
    diffutils
    findutils
    python
    patchelf
    ;
  elfPaths = [
    "bin/zstd"
    "lib/libzstd.so.${final.version}"
  ];
  environment = final.base.environment final.environment;
  checkEnvironment = final.base.environment (
    final.environment
    // {
      tools = final.environment.tools ++ [
        final.tools.python
        final.tools.gnugrep
        final.tools.diffutils
      ];
    }
  );
  command =
    name: run:
    environment
    // {
      inherit name cwd;
      run =
        ''
          export PREFIX="$out"
        ''
        + run;
    };
  make = ''${final.tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${final.bash}/bin/bash HAVE_ZLIB=1 HAVE_LZMA=1 HAVE_LZ4=0'';
  rpaths =
    {
      python,
      binutils,
      patchelf,
      base,
      paths,
      libraries,
      dlopenDirectories ? [ ],
    }:
    {
      name = "output.rpaths";
      tools = [
        python
        binutils
        patchelf
      ];
      run = ''${python}/bin/python3 -B ${../ordinary-compression-rpaths.py} "$out" ${
        lib.escapeShellArg (
          builtins.toJSON {
            inherit paths dlopenDirectories;
            elfKinds = null;
            libraries = lib.concatMap (
              p: (p.development or { }).libraryDirectories or [ "${lib.getLib p}/lib" ]
            ) libraries;
            baseDirectories = base.runtimeDirectories;
            readelf = "${binutils}/bin/readelf";
            patchelf = "${patchelf}/bin/patchelf";
          }
        )
      } ${../../../lib/native-output}'';
    };

in
{
  pname = "zstd";
  bash = baseTools.bash;
  coreutils = baseTools.coreutils;
  gnumake = baseTools.gnumake;
  gnutar = baseTools.gnutar;
  gzip = baseTools.gzip;
  gnused = baseTools.sed;
  gnugrep = baseTools.grep;
  diffutils = baseTools.diffutils;
  findutils = baseTools.findutils;
  python = baseTools.python;
  patchelf = baseTools.patchelf;

  inherit
    base
    src
    version
    ;
  tools = {
    inherit
      gnumake
      gnutar
      gzip
      findutils
      python
      binutils
      patchelf
      gnused
      gnugrep
      diffutils
      ;
  };
  libraries = {
    inherit zlib xz;
  };
  inherit doCheck;
  stripFlags = [
    "-S"
    "-p"
  ];
  # Standard tools are registered by their effective base roles.
  dependencyProviders = final.libraries;
  environment = {
    tools = [
      final.tools.gnumake
      final.tools.gnugrep
      final.tools.gnused
    ];
    libraries = [
      final.libraries.zlib
      final.libraries.xz
    ];
  };
  runtime = {
    libraries = [
      final.libraries.zlib
      final.libraries.xz
    ];
    shell = final.bash;
    pager = final.coreutils;
    tools = [
      final.coreutils
      final.tools.gnused
      final.tools.gnugrep
      final.tools.diffutils
    ];
  };
  upstreamCheck =
    (builtins.head (
      builtins.filter (
        step: step.name == "zstd.check" || step.name == "zstd.check-upstream" || step.name == "check"
      ) (steps.partition final.originalPlan).first
    ))
    // {
      enabled = final.doCheck;
    };
  originalPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      gzip = final.tools.gzip;
      findutils = final.tools.findutils;
      tar = final.tools.gnutar;
      compression = "gzip";
    })
    {
      name = "zstd.prepare";
      cwd = "source";
      tools = [ final.tools.python ];
      env = environment.env;
      run = "${final.tools.python}/bin/python3 -B ${../ordinary-compression-source.py} zstd ${final.bash}/bin/bash";
    }
    (command "zstd.build" make)
    (
      (command "zstd.check" ''
        ${make} -C tests datagen
        ${final.tools.python}/bin/python3 tests/cli-tests/run.py --zstd "$PWD/programs/zstd" --datagen "$PWD/tests/datagen" ${lib.escapeShellArgs upstreamTests}
      '')
      // {
        enabled = final.doCheck;
        tools = checkEnvironment.tools;
        env = checkEnvironment.env;
      }
    )
    (command "zstd.install" ''
      ${make} install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (steps.split "zstd.finalize")
    (outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "zstd.relocate-runtime";
      tools = [
        final.tools.python
        final.tools.patchelf
        final.tools.binutils
      ];
      run = ''${final.tools.python}/bin/python3 -B ${../ordinary-compression-output.py} "$out" "$TVP_ARTIFACT_ROOT" ${final.tools.patchelf}/bin/patchelf ${
        lib.escapeShellArg (
          builtins.toJSON {
            family = "zstd";
            readelf = "${final.tools.binutils}/bin/readelf";
            buildShell = "${final.bash}/bin/bash";
            shell = "${final.runtime.shell}/bin/bash";
            pager = "${final.runtime.pager}/bin/cat";
            paths = map (p: "${p}/bin") final.runtime.tools;
          }
        )
      }'';
    }
    (outputs.strip {
      flags = final.stripFlags;
      python = final.tools.python;
      binutils = final.tools.binutils;
      paths = elfPaths;
    })
    (outputs.stripArchives {
      python = final.tools.python;
      binutils = final.tools.binutils;
      paths = [ "lib/libzstd.a" ];
    })
    (outputs.shebangs {
      python = final.tools.python;
      paths = [
        "bin/zstdgrep"
        "bin/zstdless"
      ];
      names = [ "sh" ];
      interpreter = "${final.runtime.shell}/bin/bash";
    })
    # Only the CLI uses the optional codecs. libzstd has no codec DT_NEEDED.
    (rpaths {
      python = final.tools.python;
      binutils = final.tools.binutils;
      patchelf = final.tools.patchelf;
      base = final.base;
      paths = [ "bin/zstd" ];
      libraries = final.runtime.libraries;
    })
    (
      (rpaths {
        python = final.tools.python;
        binutils = final.tools.binutils;
        patchelf = final.tools.patchelf;
        base = final.base;
        paths = [ "lib/libzstd.so.${final.version}" ];
        libraries = [ ];
      })
      // {
        name = "output.library-rpaths";
      }
    )
    # Public shared/static API headers do not require the CLI's optional codecs.
    (outputs.development {
      python = final.tools.python;
      libraries = [ ];
    })
    {
      name = "output.manuals";
      tools = [ final.tools.gzip ];
      run = ''
        for name in zstd zstdgrep zstdless; do
          ${final.tools.gzip}/bin/gzip -cn "$out/share/man/man1/$name.1" > "$out/share/man/man1/$name.1.gz"
          rm "$out/share/man/man1/$name.1"
        done
        for name in unzstd zstdcat; do
          rm "$out/share/man/man1/$name.1"
          ln -s zstd.1.gz "$out/share/man/man1/$name.1.gz"
        done
      '';
    }
    (outputs.checkSymlinks {
      python = final.tools.python;
      paths = [
        "bin/unzstd"
        "bin/zstdcat"
        "bin/zstdmt"
        "lib/libzstd.so"
        "lib/libzstd.so.1"
        "share/man/man1/unzstd.1.gz"
        "share/man/man1/zstdcat.1.gz"
      ];
    })
    (outputs.checkPaths {
      python = final.tools.python;
      binutils = final.tools.binutils;
      patchelf = final.tools.patchelf;
      paths = elfPaths;
    })
  ];
  tvp.features = {
    doCheck = final.doCheck;
    inherit upstreamTests;
    gzip = true;
    lzma = true;
    lz4 = false;
  };
  meta = {
    description = "Zstandard compression library and command-line tools";
    homepage = "https://facebook.github.io/zstd/";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.unix;
    mainProgram = "zstd";
  };
  upstreamPlan = artifact: [
    {
      name = "zstd.restore-build-tree";
      tools = [ baseTools.python ];
      run = ''
        ${baseTools.python}/bin/python3 -B ${../../../lib/restore-checkpoint.py} ${artifact}/nix-support/zstd-build-tree "$TVP_SOURCE_ROOT"
        printf '%s\n' ${artifact} > "$TVP_SOURCE_ROOT/production-artifact"
      '';
    }
  ];
  plan =
    let
      parts = steps.partition final.originalPlan;
      production = builtins.filter (
        step:
        !(builtins.elem step.name [
          "zstd.prepare-tests"
          "zstd.check"
        ])
      ) parts.first;
    in
    production
    ++ [
      {
        name = "zstd.save-build-tree";
        tools = [
          baseTools.python
          final.coreutils
        ];
        run = ''
          ${baseTools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/nix-support/zstd-build-tree"
        '';
      }
    ]
    ++ (lib.optional parts.split (steps.split "zstd.finalize"))
    ++ [
      (builtins.head parts.second)
      {
        name = "zstd.drop-build-tree";
        tools = [ final.coreutils ];
        run = ''${final.coreutils}/bin/rm -rf -- "$out/nix-support/zstd-build-tree"'';
      }
    ]
    ++ builtins.tail parts.second;

}
