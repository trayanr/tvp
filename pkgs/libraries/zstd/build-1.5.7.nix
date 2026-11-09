# Native source-GNU 1.5.7 procedure; independent of the retained pilot.
# Direct Make defaults: lib-release/zstd-release and the upstream install layout.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  gnutar,
  findutils,
  gzip,
  gnumake,
  gnused,
  gnugrep,
  diffutils,
  python,
  binutils,
  patchelf,
  zlib,
  xz,
  doCheck ? true,
}:
let
  inherit (tvp.builder) steps outputs;
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
in
final:
let
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
  inherit
    base
    src
    version
    bash
    coreutils
    ;
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
  plan = steps.sequence [
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
        enabled = doCheck;
      }
    )
    (command "zstd.build" make)
    (
      (command "zstd.check" ''
        ${make} -C tests datagen
        ${python}/bin/python3 tests/cli-tests/run.py --zstd "$PWD/programs/zstd" --datagen "$PWD/tests/datagen" ${lib.escapeShellArgs upstreamTests}
      '')
      // {
        enabled = doCheck;
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
    inherit doCheck upstreamTests;
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
}
