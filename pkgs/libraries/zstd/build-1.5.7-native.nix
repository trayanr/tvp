# Native source-GNU 1.5.7 procedure; independent of the retained pilot.
# Direct Make defaults: lib-release/zstd-release and the upstream install layout.
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
}@args:

final:
let
  inherit (final)
    base
    src
    version
    bash
    coreutils
    gnutar
    findutils
    gzip
    gnumake
    gnused
    gnugrep
    diffutils
    python
    binutils
    patchelf
    zlib
    xz
    ;
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs;
  baseTools = context.tools;
  upstreamTests = [
    "basic/help.sh"
    "basic/version.sh"
    "compression/basic.sh"
    "compression/gzip-compat.sh"
    "decompression/pass-through.sh"
  ];
  cwd = "../zstd-${version}";
  elfPaths = [
    "bin/zstd"
    "lib/libzstd.so.${version}"
  ];
  environment = final.base.environment final.environment;
  checkEnvironment = final.base.environment (
    final.environment
    // {
      tools = final.environment.tools ++ [
        python
        gnugrep
        diffutils
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
  make = ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash HAVE_ZLIB=1 HAVE_LZMA=1 HAVE_LZ4=0'';
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

  inherit (args)
    base
    src
    version
    binutils
    zlib
    xz
    ;
  inherit doCheck;
  environment = {
    tools = [
      gnumake
      gnugrep
      gnused
    ];
    libraries = [
      zlib
      xz
    ];
  };
  runtime.libraries = [
    zlib
    xz
  ];
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
      inherit gzip findutils;
      tar = gnutar;
      compression = "gzip";
    })
    {
      name = "zstd.prepare";
      # Upstream realpath/__FILE__ assertions embed this source placement in code.
      run = ''mv source "../zstd-${version}"'';
    }
    (
      (steps.shebangs {
        name = "zstd.prepare-tests";
        inherit python cwd;
        paths = [ "tests/cli-tests" ];
        names = [
          "sh"
          "bash"
        ];
        interpreter = "${bash}/bin/bash";
      })
      // {
        enabled = final.doCheck;
      }
    )
    (command "zstd.build" make)
    (
      (command "zstd.check" ''
        ${make} -C tests datagen
        ${python}/bin/python3 tests/cli-tests/run.py --zstd "$PWD/programs/zstd" --datagen "$PWD/tests/datagen" ${lib.escapeShellArgs upstreamTests}
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
    (outputs.copyArtifacts { inherit coreutils; })
    (outputs.relocateText {
      inherit python;
      paths = [ "lib/pkgconfig/libzstd.pc" ];
    })
    (outputs.strip {
      inherit python binutils;
      paths = elfPaths;
    })
    (outputs.stripArchives {
      inherit python binutils;
      paths = [ "lib/libzstd.a" ];
    })
    (outputs.shebangs {
      inherit python;
      paths = [
        "bin/zstdgrep"
        "bin/zstdless"
      ];
      names = [ "sh" ];
      interpreter = "${final.bash}/bin/bash";
    })
    # Only the CLI uses the optional codecs. libzstd has no codec DT_NEEDED.
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      paths = [ "bin/zstd" ];
      libraries = final.runtime.libraries;
    })
    (
      (outputs.rpaths {
        inherit python binutils patchelf;
        base = final.base;
        paths = [ "lib/libzstd.so.${version}" ];
        libraries = [ ];
      })
      // {
        name = "output.library-rpaths";
      }
    )
    # Public shared/static API headers do not require the CLI's optional codecs.
    (outputs.development {
      inherit python;
      libraries = [ ];
    })
    {
      name = "output.manuals";
      tools = [ gzip ];
      run = ''
        for name in zstd zstdgrep zstdless; do
          ${gzip}/bin/gzip -cn "$out/share/man/man1/$name.1" > "$out/share/man/man1/$name.1.gz"
          rm "$out/share/man/man1/$name.1"
        done
        for name in unzstd zstdcat; do
          rm "$out/share/man/man1/$name.1"
          ln -s zstd.1.gz "$out/share/man/man1/$name.1.gz"
        done
      '';
    }
    (outputs.checkSymlinks {
      inherit python;
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
      inherit python binutils patchelf;
      paths = elfPaths;
    })
  ];
  tvp.features = {
    inherit upstreamTests;
    doCheck = final.doCheck;
    gzip = true;
    lzma = true;
    lz4 = false;
  };
  meta = {
    description = "Zstandard compression library and command-line tools";
    homepage = "https://facebook.github.io/zstd/";
    license = lib.licenses.bsd3;
    platforms = [ "x86_64-linux" ];
    mainProgram = "zstd";
  };
  upstreamPlan = artifact: [
    {
      name = "zstd.restore-build-tree";
      tools = [ baseTools.python ];
      run = ''
        ${baseTools.python}/bin/python3 -B ${../../../lib/utilities-checkpoint.py} restore ${artifact}/nix-support/zstd-build-tree "$TVP_SOURCE_ROOT"
        printf '%s\n' ${artifact} > "$TVP_SOURCE_ROOT/production-artifact"
      '';
    }
    {
      name = "zstd.prepare-upstream-frontends";
      tools = [ baseTools.python ];
      run = ''
        cd "$(cat "$TVP_SOURCE_ROOT/tree-path")"
        ${(steps.shebangs {
          name = "zstd.test-shells";
          python = baseTools.python;
          paths = [ "tests/cli-tests" ];
          names = [
            "sh"
            "bash"
          ];
          interpreter = "${final.bash}/bin/bash";
        }).run
        }
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
          sourcePath=$(${final.coreutils}/bin/realpath "$TVP_SOURCE_ROOT/../zstd-${final.version}")
          ${baseTools.python}/bin/python3 -B ${../../../lib/utilities-checkpoint.py} save "$TVP_SOURCE_ROOT" "$out/nix-support/zstd-build-tree" "[\"$sourcePath\"]" "$sourcePath"
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
