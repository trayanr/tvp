{
  pkgs,
  tvp,
  tvpLib,
  package,
}:
let
  deps = package.tvp.deps;
  ninja = package.tvp.declaredTestDependencies.ninja;
  source = ./fixtures;
  consumer = generator: program: ''
    cmake -S ${source} -B build -G '${generator}' -DCMAKE_MAKE_PROGRAM=${program} \
      -DCMAKE_INSTALL_PREFIX="$PWD/installed" -DCMAKE_INSTALL_LIBDIR=lib >&2
    cmake --build build --parallel "$NIX_BUILD_CORES" >&2
    ctest --test-dir build --output-on-failure >&2
    cmake --install build >&2
    env -i installed/bin/answer
  '';
in
package.testContext.mkSuite {
  inherit package;
  tools = [
    deps.gnumake
    deps.gawk
    deps.grep
    ninja
  ];
  libraries = [ deps.zlib ];
  tests = {
    profile = {
      script = ''test -s ${
        (import ./native-profile.nix {
          inherit
            pkgs
            tvp
            package
            ninja
            ;
        }).evidence
      }/success.json; printf qualified'';
      expected = "qualified";
    };
    version = {
      script = ''cmake --version | head -1 | awk '{print $3}' '';
      expected = package.version;
    };
    make = {
      script = consumer "Unix Makefiles" "${deps.gnumake}/bin/make";
      expected = "42";
    };
    ninja = {
      script = consumer "Ninja" "${ninja}/bin/ninja";
      expected = "42";
    };
    archives = {
      script = ''
        cmake -S ${source} -B build -G 'Unix Makefiles' -DCMAKE_MAKE_PROGRAM=${deps.gnumake}/bin/make >&2
        cmake --build build --parallel "$NIX_BUILD_CORES" >&2
        ctest --test-dir build --output-on-failure >&2
        cd build
        for generator in TGZ TBZ2 TXZ TZST; do
          cpack -G "$generator" >&2
        done
        for archive in answer-1.0.0-Linux.tar.*; do
          cmake -E tar tf "$archive" | grep -E '/bin/answer$' >&2
          mkdir unpack
          (cd unpack; cmake -E tar xf "../$archive")
          test "$(env -i LD_LIBRARY_PATH="$PWD/unpack/answer-1.0.0-Linux/lib" unpack/answer-1.0.0-Linux/bin/answer)" = 42
          rm -rf unpack
        done
        printf 42
      '';
      expected = "42";
    };
    modules = {
      script = ''
        printf 'include(CMakeParseArguments)\nmessage(STATUS "ROOT=''${CMAKE_ROOT}")\n' > probe.cmake
        env -i ${package}/bin/cmake -P probe.cmake | grep -F '${package}/share/cmake-4.4' >&2
        env -i ${package}/bin/ctest --version >&2
        env -i ${package}/bin/cpack --version >&2
        printf installed
      '';
      expected = "installed";
    };
  };
}

// {
  constructor = import ../../native-frontend-contract.nix { inherit pkgs tvp package; };
}
