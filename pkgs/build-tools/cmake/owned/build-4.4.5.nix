# The canonical feature policy, expressed through the owned step runner.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  python,
  gnumake,
  gnutar,
  gzip,
  findutils,
  patch,
  sed,
  grep,
  gawk,
  diffutils,
  pkgConfig,
  openssl,
  zlib,
  bzip2,
  xz,
  zstd,
  binutils,
  patchelf,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      inherit name;
      cwd = "source";
      run = ''
        mkdir -p "$evidence"
        status=0
        ${bash}/bin/bash -euc ${lib.escapeShellArg run} > "$evidence/${name}.log" 2>&1 || status=$?
        printf '%s\n' "$status" > "$evidence/${name}.status"
        if (( status )); then cat "$evidence/${name}.log"; exit "$status"; fi
      '';
    };
in
{
  pname = "cmake";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  outputs = [
    "out"
    "evidence"
  ];
  buildEnvironment = import ../build-environment.nix { inherit lib; };
  environment = {
    tools = [
      gnumake
      findutils
      patch
      sed
      grep
      gawk
      diffutils
      pkgConfig
      python
    ];
    libraries = [
      openssl
      zlib
      bzip2
      xz
      zstd
    ];
  };
  runtime.libraries = (final.base.environment final.environment).libraries;
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit gzip findutils;
      compression = "gzip";
    })
    (command "cmake.prepare" ''
      ${patch}/bin/patch -p1 < ${../patches/store-shell.patch}
      ${python}/bin/python3 -B - ${lib.escapeShellArg "${bash}/bin/bash"} <<'PY'
      from pathlib import Path
      import sys
      shell = sys.argv[1]
      for name in ['Source/cmLocalUnixMakefileGenerator3.cxx', 'Source/cmExecProgramCommand.cxx']:
          p = Path(name)
          text = p.read_text()
          assert '@TVP_SHELL@' in text
          p.write_text(text.replace('@TVP_SHELL@', shell))
      p = Path('bootstrap')
      text = p.read_text()
      assert text.startswith('#!/bin/sh\n')
      p.write_text('#!' + shell + '\n' + text.split('\n', 1)[1])
      PY
    '')
    # Auxiliary module scripts/templates retain their contents and explicit shell.
    (steps.shebangs {
      name = "cmake.source-shells";
      inherit python;
      paths = [
        "Modules/Compiler/XL-Fortran/cpp"
        "Modules/Internal/CPack/CPack.RuntimeScript.in"
        "Modules/Internal/CPack/CPack.STGZ_Header.sh.in"
        "Modules/Platform/AIX/ExportImportList"
        "Modules/Squish4RunTestCase.sh"
        "Modules/SquishRunTestCase.sh"
      ];
      names = [
        "sh"
        "bash"
      ];
      interpreter = "${bash}/bin/bash";
    })
    (command "cmake.configure" ''
      # 4.4.5's bootstrap forces the cache options from its selectors. Keep
      # the bundled default and explicitly exempt the four selected codecs.
      ./bootstrap --prefix="$out" --parallel="$NIX_BUILD_CORES" --no-system-libs \
        --system-zlib --system-bzip2 --system-liblzma --system-zstd -- \
        -DBUILD_TESTING=OFF \
        -DCMAKE_PREFIX_PATH=${
          lib.escapeShellArg (
            lib.concatStringsSep ";" (
              map (p: "${lib.getDev p}") ([ final.base.stdenv.cc.libc ] ++ final.environment.libraries)
            )
          )
        } \
        -DCMAKE_USE_OPENSSL=ON -DOPENSSL_ROOT_DIR=${openssl} \
        -DCMAKE_USE_SYSTEM_ZLIB=ON -DCMAKE_USE_SYSTEM_BZIP2=ON \
        -DCMAKE_USE_SYSTEM_LIBLZMA=ON -DCMAKE_USE_SYSTEM_ZSTD=ON
      cp CMakeCache.txt "$evidence/"
      ${python}/bin/python3 -B - <<'PY'
      from pathlib import Path
      cache = Path('CMakeCache.txt').read_text()
      for name in ['ZLIB', 'BZIP2', 'LIBLZMA', 'ZSTD']:
          assert 'CMAKE_USE_SYSTEM_' + name + ':BOOL=ON' in cache
      assert 'CMAKE_USE_OPENSSL:BOOL=ON' in cache
      assert 'BUILD_TESTING:BOOL=OFF' in cache
      PY
    '')
    (command "cmake.build" ''make -j"$NIX_BUILD_CORES"'')
    (command "cmake.install" ''make install'')
    (outputs.strip {
      inherit python binutils;
      paths = [ "bin" ];
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      paths = [ "bin" ];
      libraries = final.runtime.libraries;
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = [ "bin" ];
    })
  ];
  meta = {
    description = "Cross-platform build-system generator, CTest and CPack";
    homepage = "https://cmake.org/";
    license = lib.licenses.bsd3;
    platforms = [ "x86_64-linux" ];
    mainProgram = "cmake";
  };
}
