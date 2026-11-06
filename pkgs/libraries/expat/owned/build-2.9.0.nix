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
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "expat.${name}";
      run = ''
        mkdir -p "$evidence"
        status=0
        ${bash}/bin/bash -euc ${lib.escapeShellArg run} > "$evidence/expat.${name}.log" 2>&1 || status=$?
        printf '%s\n' "$status" > "$evidence/expat.${name}.status"
        if [[ ${lib.escapeShellArg name} == check ]]; then
          cp -r build/Testing "$evidence/Testing" || true
        elif (( status )); then cat "$evidence/expat.${name}.log"; exit "$status"; fi
      '';
    };
in
{
  pname = "expat";
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
    ] ++ buildTools;
    libraries = [ ];
  };
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      inherit xz gzip findutils;
      tar = gnutar;
      compression = "xz";
    })

    (command "configure" ''
      ${cmake}/bin/cmake -S source -B build -G Ninja -DCMAKE_MAKE_PROGRAM=${ninja}/bin/ninja \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_INSTALL_PREFIX="$out" -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_RPATH="$out/lib" \
        -DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF -DCMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY=OFF -DEXPAT_BUILD_DOCS=OFF -DEXPAT_BUILD_TESTS=ON -DEXPAT_BUILD_TOOLS=ON -DEXPAT_BUILD_EXAMPLES=ON
    '')
    (command "build" ''${cmake}/bin/cmake --build build --parallel "$NIX_BUILD_CORES" --verbose'')
    (command "check" ''${cmake}/bin/ctest --test-dir build --output-on-failure --no-tests=error -j "$NIX_BUILD_CORES"'')
    (command "install" ''${cmake}/bin/cmake --install build'')
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
      libraries = [ ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = [
        "bin"
        "lib"
      ];
    })
  ];
  meta.platforms = [ "x86_64-linux" ];
}
