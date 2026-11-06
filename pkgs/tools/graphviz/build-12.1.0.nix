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
  pkgConfig,
  bison,
  flex,
  gd,
  freetype,
  fontconfig,
  expat,
  ltdl,
  zlib,
  patch,
  patches,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "graphviz.${name}";
      run = ''
        mkdir -p "$evidence"
        status=0
        ${bash}/bin/bash -euc ${lib.escapeShellArg run} > "$evidence/graphviz.${name}.log" 2>&1 || status=$?
        printf '%s\n' "$status" > "$evidence/graphviz.${name}.status"
        if [[ ${lib.escapeShellArg name} == check ]]; then
          cp -r build/Testing "$evidence/Testing" || true
        elif (( status )); then cat "$evidence/graphviz.${name}.log"; exit "$status"; fi
      '';
    };
in
{
  pname = "graphviz";
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
      bison
      flex
    ] ++ buildTools;
    libraries = [
      gd
      freetype
      fontconfig
      expat
      ltdl
      zlib
    ];
  };
  runtime.libraries = [
    gd
    freetype
    fontconfig
    expat
    ltdl
    zlib
  ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      inherit xz gzip findutils;
      tar = gnutar;
      compression = "gzip";
    })
    {
      name = "graphviz.patch";
      tools = [ patch ];
      cwd = "source";
      run = lib.concatMapStringsSep "\n" (p: "${patch}/bin/patch -p1 < ${p}") patches;
    }
    (command "configure" ''
      ${cmake}/bin/cmake -S source -B build -G Ninja -DCMAKE_MAKE_PROGRAM=${ninja}/bin/ninja \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_INSTALL_PREFIX="$out" -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_EXE_LINKER_FLAGS="-Wl,-rpath-link,$PWD/build/lib/pathplan -Wl,-rpath-link,$PWD/build/lib/xdot" \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_RPATH="$out/lib" \
        -DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF -DCMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY=OFF -DENABLE_LTDL=ON -DENABLE_TCL=OFF -DENABLE_SWIG=OFF -DENABLE_SHARP=OFF -DENABLE_D=OFF -DENABLE_GO=OFF -DENABLE_JAVASCRIPT=OFF -Dwith_sfdp=OFF -Dwith_digcola=OFF -Dwith_ipsepcola=OFF -DCMAKE_DISABLE_FIND_PACKAGE_ANN=TRUE -DCMAKE_DISABLE_FIND_PACKAGE_CAIRO=TRUE -DCMAKE_DISABLE_FIND_PACKAGE_GTS=TRUE -DCMAKE_DISABLE_FIND_PACKAGE_GLUT=TRUE -DCMAKE_DISABLE_FIND_PACKAGE_GTK2=TRUE -DCMAKE_DISABLE_FIND_PACKAGE_GS=TRUE -DCMAKE_DISABLE_FIND_PACKAGE_DevIL=TRUE -DCMAKE_DISABLE_FIND_PACKAGE_PANGOCAIRO=TRUE
    '')
    (command "build" ''${cmake}/bin/cmake --build build --parallel "$NIX_BUILD_CORES" --verbose'')
    (command "check" ''${cmake}/bin/ctest --test-dir build --output-on-failure --no-tests=error -j "$NIX_BUILD_CORES"'')
    (command "install" ''${cmake}/bin/cmake --install build'')
    {
      name = "graphviz.linked-plugin-paths";
      tools = [ patchelf ];
      run = ''
        for program in dot_builtins gvpack; do
          ${patchelf}/bin/patchelf --add-rpath "$out/lib/graphviz" "$out/bin/$program"
        done
      '';
    }
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      paths = [
        "bin"
        "lib"
      ];
      libraries = final.runtime.libraries;
    })
    {
      name = "graphviz.registry";
      run = ''
        "$out/bin/dot" -c
        test -s "$out/lib/graphviz/config6"
        cp "$out/lib/graphviz/config6" "$evidence/config6"
      '';
    }
    (outputs.development {
      inherit python;
      libraries = [
        gd
        freetype
        fontconfig
        expat
        ltdl
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
    svg = true;
    html = true;
    freetype = true;
    fontconfig = true;
    gif = true;
    jpeg = false;
    ltdl = true;
    cairo = false;
    pango = false;
    bindings = false;
  };
  meta.platforms = [ "x86_64-linux" ];
}
