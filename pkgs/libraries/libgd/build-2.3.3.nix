# Complete owned CMake procedure for the selected rendering floor.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  gnutar,
  xz,
  gzip,
  findutils,
  python,
  binutils,
  patchelf,
  cmake,
  ninja,
  buildTools,
  fontData,
  perl,
  pkgConfig,
  png,
  freetype,
  fontconfig,
  zlib,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "gd.${name}";
      run = ''
        mkdir -p "$evidence"
        status=0
        ${bash}/bin/bash -euc ${lib.escapeShellArg run} > "$evidence/gd.${name}.log" 2>&1 || status=$?
        printf '%s\n' "$status" > "$evidence/gd.${name}.status"
        if [[ ${lib.escapeShellArg name} == check ]]; then
          cp -r build/Testing "$evidence/Testing" || true
        elif (( status )); then cat "$evidence/gd.${name}.log"; exit "$status"; fi
      '';
    };
in
{
  pname = "gd";
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
  environment = {
    tools = [
      cmake
      ninja
      python
      pkgConfig
    ] ++ buildTools;
    libraries = [
      png
      freetype
      fontconfig
      zlib
    ];
  };
  runtime.interpreters = [ perl ];
  runtime.libraries = [
    png
    freetype
    fontconfig
    zlib
  ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      inherit xz gzip findutils;
      tar = gnutar;
      compression = "gzip";
    })
    (steps.shebangs {
      name = "gd.prepare";
      inherit python;
      interpreter = "${bash}/bin/bash";
      names = [ "sh" ];
      paths = [
        "config/getver.sh"
        "config/getlib.sh"
      ];
    })
    (command "configure" ''
      ${cmake}/bin/cmake -S source -B build -G Ninja -DCMAKE_MAKE_PROGRAM=${ninja}/bin/ninja \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_INSTALL_PREFIX="$out" -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_RPATH="$out/lib" \
        -DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF -DCMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY=OFF -DENABLE_PNG=ON -DENABLE_FREETYPE=ON -DENABLE_FONTCONFIG=ON -DENABLE_CPP=ON -DBUILD_TEST=ON -DENABLE_GD_FORMATS=OFF -DCMAKE_DISABLE_FIND_PACKAGE_OpenMP=TRUE -DENABLE_LIQ=OFF -DENABLE_JPEG=OFF -DENABLE_TIFF=OFF -DENABLE_ICONV=OFF -DENABLE_XPM=OFF -DENABLE_WEBP=OFF -DENABLE_HEIF=OFF -DENABLE_AVIF=OFF -DENABLE_RAQM=OFF -DENABLE_ASAN=OFF
    '')
    (command "build" ''${cmake}/bin/cmake --build build --parallel "$NIX_BUILD_CORES" --verbose'')
    (command "check" ''
      export FONTCONFIG_FILE=${fontData}/etc/fonts/fonts.conf
      export HOME="$PWD/test-home" XDG_CACHE_HOME="$PWD/test-cache"
      mkdir -p "$HOME" "$XDG_CACHE_HOME"
      ${cmake}/bin/ctest --test-dir build --output-on-failure --no-tests=error -j "$NIX_BUILD_CORES"'')
    (command "install" ''${cmake}/bin/cmake --install build'')
    (outputs.shebangs {
      inherit python;
      paths = [ "bin/bdftogd" ];
      names = [ "perl" ];
      interpreter = "${perl}/bin/perl";
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      paths = [
        "bin"
        "lib"
      ];
      libraries = final.runtime.libraries;
    })

    (outputs.development {
      inherit python;
      libraries = [
        png
        freetype
        fontconfig
        zlib
      ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = [
        "bin"
        "lib"
      ];
    })
  ];
  tvp.features = {
    png = true;
    freetype = true;
    fontconfig = true;
    gif = true;
    jpeg = false;
    tiff = false;
    webp = false;
    heif = false;
    avif = false;
    xpm = false;
    openmp = false;
  };
  meta.platforms = [ "x86_64-linux" ];
}
