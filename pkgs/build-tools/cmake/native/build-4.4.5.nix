# Native ordinary 4.4.5: TLS, four system codecs and complete module/tool payload.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  helperPython,
  gnumake,
  gnutar,
  gzip,
  findutils,
  patch,
  sed,
  grep,
  gawk,
  diffutils,
  pkg-config,
  openssl,
  zlib,
  bzip2,
  xz,
  zstd,
  binutils,
  patchelf,
  patches,
  docDirectory,
  bundledLicenseFiles,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  environment = final.base.environment final.environment;
  # The selected compiler wrapper is an explicit tool interface. Keep required
  # transitive development paths when callers replace upstream scalar flags or
  # the structured flag defaults; no ambient NIX_* values participate.
  requiredEnvironment = final.base.environment {
    libraries = final.environment.libraries or [ ];
  };
  customCompile =
    environment.env ? CFLAGS
    || environment.env ? CXXFLAGS
    || environment.env ? CPPFLAGS
    || (final.environment.overrides.flags or { }) ? NIX_CFLAGS_COMPILE;
  customLink = environment.env ? LDFLAGS || (final.environment.overrides.flags or { }) ? NIX_LDFLAGS;
  compileFlags = environment.environmentContributions.NIX_CFLAGS_COMPILE.value;
  linkFlags = environment.environmentContributions.NIX_LDFLAGS.value;
  command =
    name: run:
    environment
    // {
      inherit name;
      cwd = "source";
      env = environment.env // {
        NIX_CFLAGS_COMPILE =
          if customCompile then
            lib.concatStringsSep " " requiredEnvironment.environmentContributions.NIX_CFLAGS_COMPILE.value
          else
            "";
        NIX_LDFLAGS =
          if customLink then
            lib.concatStringsSep " " requiredEnvironment.environmentContributions.NIX_LDFLAGS.value
          else
            "";
        CFLAGS = environment.env.CFLAGS or (lib.concatStringsSep " " compileFlags);
        CXXFLAGS = environment.env.CXXFLAGS or (lib.concatStringsSep " " compileFlags);
        LDFLAGS = environment.env.LDFLAGS or (lib.concatMapStringsSep " " (f: "-Wl,${f}") linkFlags);
      };
      run = ''
          mkdir -p "$NIX_BUILD_TOP/evidence"
          status=0
          ${final.bash}/bin/bash -euc ${lib.escapeShellArg run} > "$NIX_BUILD_TOP/evidence/${name}.log" 2>&1 || status=$?
          printf '%s\n' "$status" > "$NIX_BUILD_TOP/evidence/${name}.status"
          cat "$NIX_BUILD_TOP/evidence/${name}.log" >&2
        if (( status )); then exit "$status"; fi
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
      pkg-config
      helperPython
    ];
    libraries = [
      openssl
      zlib
      bzip2
      xz
      zstd
    ];
  };
  runtime = {
    libraries = environment.libraries;
    shell = bash;
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = gnutar;
      inherit gzip findutils;
      compression = "gzip";
    })
    (command "cmake.prepare" ''
      ${lib.concatMapStringsSep "\n" (p: ''${patch}/bin/patch --batch --fuzz=0 -p1 < ${p}'') patches}
      ${helperPython}/bin/python3 -B - ${lib.escapeShellArg "${final.runtime.shell}/bin/bash"} <<'PY'
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
      python = helperPython;
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
      interpreter = "${final.runtime.shell}/bin/bash";
    })
    (command "cmake.configure" ''
      # 4.4.5's bootstrap forces the cache options from its selectors. Keep
      # the bundled default and explicitly exempt the four selected codecs.
      ./bootstrap --prefix="$out" --docdir=${lib.escapeShellArg docDirectory} --parallel="$NIX_BUILD_CORES" --no-system-libs \
        --system-zlib --system-bzip2 --system-liblzma --system-zstd -- \
        -DBUILD_TESTING=OFF \
        -DCMAKE_PREFIX_PATH=${
          lib.escapeShellArg (
            lib.concatStringsSep ";" (
              map (p: "${lib.getDev p}") ([ final.base.compiler.libc ] ++ final.environment.libraries)
            )
          )
        } \
        -DCMAKE_USE_OPENSSL=ON -DOPENSSL_ROOT_DIR=${openssl} \
        -DCMAKE_USE_SYSTEM_ZLIB=ON -DCMAKE_USE_SYSTEM_BZIP2=ON \
        -DCMAKE_USE_SYSTEM_LIBLZMA=ON -DCMAKE_USE_SYSTEM_ZSTD=ON
      cp CMakeCache.txt "$NIX_BUILD_TOP/evidence/"
      cat CMakeCache.txt >&2
      ${helperPython}/bin/python3 -B - <<'PY'
      from pathlib import Path
      cache = Path('CMakeCache.txt').read_text()
      for name in ['ZLIB', 'BZIP2', 'LIBLZMA', 'ZSTD']:
          assert 'CMAKE_USE_SYSTEM_' + name + ':BOOL=ON' in cache
      assert 'CMAKE_USE_OPENSSL:BOOL=ON' in cache
      assert 'BUILD_TESTING:BOOL=OFF' in cache
      PY
    '')
    (command "cmake.build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
    (command "cmake.install" ''
      ${gnumake}/bin/make install
      for document in ${lib.escapeShellArgs bundledLicenseFiles}; do
        install -Dm644 "$document" "$out/${docDirectory}/''${document#Utilities/}"
      done
      install -Dm644 ${../setup-hook.sh} "$out/nix-support/setup-hook"
    '')
    (outputs.strip {
      python = helperPython;
      inherit binutils;
      paths = [ "bin" ];
    })
    (outputs.rpaths {
      python = helperPython;
      inherit binutils patchelf;
      base = final.base;
      paths = [ "bin" ];
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
    })
    (outputs.checkPaths {
      python = helperPython;
      inherit binutils patchelf;
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
