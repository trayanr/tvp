# 2.9.0: public CMake/Ninja source-GNU procedure; CTest runs in independent validation.
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
  findutils,
  python,
  binutils,
  patchelf,
  cmake,
  ninja,
  doCheck ? true,
}:
final:
let
  inherit (tvp.builder) steps outputs;
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "expat.${name}";
      inherit run;
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
  tools = {
    inherit
      gnutar
      xz
      findutils
      python
      binutils
      patchelf
      cmake
      ninja
      ;
  };
  environment = {
    tools = with final.tools; [
      cmake
      ninja
    ];
    libraries = [ ];
  };
  runtime.libraries = [ ];
  development = {
    includeDirectories = [ "include" ];
    libraries = [ ];
  };
  cmakeFlags = [
    "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
    "-DCMAKE_INSTALL_LIBDIR=lib"
    "-DCMAKE_BUILD_TYPE=Release"
    "-DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF"
    "-DCMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY=OFF"
    "-DEXPAT_BUILD_DOCS=OFF"
    "-DEXPAT_BUILD_TESTS=ON"
    "-DEXPAT_BUILD_TOOLS=ON"
    "-DEXPAT_BUILD_EXAMPLES=ON"
  ];
  artifactPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.tools.gnutar;
      inherit (final.tools) xz findutils;
      compression = "xz";
    })
    (command "configure" ''
      ${final.tools.cmake}/bin/cmake -S source -B build -G Ninja \
        -DCMAKE_MAKE_PROGRAM=${final.tools.ninja}/bin/ninja -DCMAKE_INSTALL_PREFIX="$out" \
        -DCMAKE_INSTALL_RPATH="$out/lib" ${
          lib.escapeShellArgs (
            lib.filter (flag: flag != "-DEXPAT_BUILD_TESTS=ON") final.cmakeFlags
            ++ [ "-DEXPAT_BUILD_TESTS=OFF" ]
          )
        }
    '')
    (command "build" ''${final.tools.cmake}/bin/cmake --build build --parallel "$NIX_BUILD_CORES" --verbose'')
    (command "install" ''
      ${final.tools.cmake}/bin/cmake --install build
      mkdir -p "$out/share/licenses/expat"
      cp source/COPYING "$out/share/licenses/expat/"
    '')
  ];
  inherit doCheck;
  upstreamPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      tar = final.tools.gnutar;
      inherit (final.tools) xz findutils;
      compression = "xz";
    })
    (command "configure" ''
      ${final.tools.cmake}/bin/cmake -S source -B build -G Ninja \
        -DCMAKE_MAKE_PROGRAM=${final.tools.ninja}/bin/ninja -DCMAKE_INSTALL_PREFIX="$out" \
        -DCMAKE_INSTALL_RPATH="$out/lib" ${lib.escapeShellArgs final.cmakeFlags}
    '')
    (command "build" ''${final.tools.cmake}/bin/cmake --build build --parallel "$NIX_BUILD_CORES" --verbose'')
  ];
  upstreamCheck = (
    (command "check" ''${final.tools.cmake}/bin/ctest --test-dir build --output-on-failure --no-tests=error -j "$NIX_BUILD_CORES"'')
    // {
      enabled = final.tvp.features.doCheck;
    }
  );
  plan = steps.sequence (
    final.artifactPlan
    ++ [
      (steps.split "expat.finalize")
      (outputs.copyArtifacts { coreutils = final.coreutils; })
      (outputs.relocateText {
        inherit python;
        paths = [
          "lib/pkgconfig"
          "lib/cmake"
        ];
      })
      (outputs.strip {
        inherit (final.tools) python binutils;
        paths = [
          "bin"
          "lib"
        ];
      })
      (outputs.rpaths {
        inherit (final.tools) python binutils patchelf;
        base = final.base;
        paths = [
          "bin"
          "lib"
        ];
        libraries = final.runtime.libraries;
      })
      (outputs.development {
        inherit (final.tools) python;
        libraries = final.development.libraries;
      })
      (outputs.checkPaths {
        inherit (final.tools) python binutils patchelf;
        paths = [
          "bin"
          "lib"
        ];
      })
    ]
  );
  tvp.features = {
    inherit doCheck;
    shared = true;
    static = false;
  };
  meta = {
    description = "Streaming XML parser library and xmlwf tool";
    homepage = "https://libexpat.github.io/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
