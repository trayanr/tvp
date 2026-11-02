# Opt-in direct-Make recipe, retaining upstream release and install defaults.
{
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  gnutar,
  gzip,
  gnumake,
  gnused,
  gnugrep,
  diffutils,
  python,
  zlib,
  xz,
  doCheck ? true,
}:
let
  helpers = import ../../../lib/native-steps.nix { inherit lib; };
  upstreamTests = "basic/help.sh basic/version.sh compression/basic.sh compression/gzip-compat.sh decompression/pass-through.sh";
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
  plan =
    helpers.unpack {
      inherit src gzip;
      tar = gnutar;
      compression = "gzip";
    }
    ++ [
      {
        name = "zstd.prepare";
        # libzstd's Makefile uses realpath, and an enabled assertion embeds
        # __FILE__. Retain canonical source placement for byte-identical code.
        run = ''mv source "../zstd-${version}"'';
      }
    ]
    ++
      map
        (
          step:
          step
          // {
            tools =
              step.tools
              ++ lib.optionals (step.name == "zstd.check") [
                python
                gnugrep
                diffutils
              ];
            # PREFIX is an upstream ?= default, exported to every recursive Make.
            # Keep CC/CXX/AR and flags from the selected base/setup and upstream.
            run =
              ''export PREFIX="$out"''
              + "\n"
              + step.run
              + "\n"
              + lib.optionalString (step.name == "zstd.check") ''
                # Patch only test launchers; shipped helper scripts are finalized
                # exactly as in the canonical build.
                export NIX_STORE=${lib.escapeShellArg builtins.storeDir}
                set +u
                patchShebangs --build tests/cli-tests
                set -u
                ${python}/bin/python3 tests/cli-tests/run.py --zstd "$PWD/programs/zstd" --datagen "$PWD/tests/datagen" ${upstreamTests}
              '';
          }
        )
        (
          helpers.make {
            name = "zstd";
            cwd = "../zstd-${version}";
            make = gnumake;
            tools = [ gnused ];
            libraries = [
              zlib
              xz
            ];
            makeFlags = [
              "SHELL=${bash}/bin/bash"
              "HAVE_ZLIB=1"
              "HAVE_LZMA=1"
              "HAVE_LZ4=0"
            ];
            # Empty build targets select default: lib-release and zstd-release.
            inherit doCheck;
            checkTargets = [
              "-C"
              "tests"
              "datagen"
            ];
          }
        )
    # A bounded selection from the shipped CLI suite, not the upstream long
    # test/fuzz/benchmark targets. Python executes the installed test scripts.
    ++ map (
      step:
      step
      // {
        # The retained shebang hook needs this in a fresh runner environment.
        run = "export NIX_STORE=${lib.escapeShellArg builtins.storeDir}\n" + step.run;
      }
    ) (helpers.finalize { });
  runtime.libraries = [
    (lib.getLib zlib)
    (lib.getLib xz)
  ];
  tvp.features = {
    inherit doCheck;
    gzip = true;
    lzma = true;
    lz4 = false;
    upstreamTests = lib.splitString " " upstreamTests;
  };
  meta = {
    description = "Zstandard compression library and command-line tools";
    homepage = "https://facebook.github.io/zstd/";
    license = lib.licenses.bsd3;
    platforms = [ "x86_64-linux" ];
    mainProgram = "zstd";
  };
}
