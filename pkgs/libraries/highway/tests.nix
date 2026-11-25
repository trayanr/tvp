{ package, context, ... }:
let
  inherit (package.specification.base) tools;
in
context.mkSuite {
  inherit package;
  libraries = [ package ];
  tests = {
    pkg-config = {
      tools = [ tools.pkg-config ];
      script = ''
        for lib in libhwy libhwy-contrib libhwy-test; do
          test "$(pkg-config --modversion "$lib")" = "${package.version}"
        done
        "$CXX" -std=c++17 ${./consumer.cc} \
          $(pkg-config --cflags --libs libhwy-contrib libhwy-test libhwy) -o consumer
        ./consumer
      '';
      expected = "Highway dispatch";
    };
    cmake = {
      tools = [
        tools.cmake
        tools.ninja
      ];
      script = ''
        cp ${./consumer.cc} consumer.cc
        cat > CMakeLists.txt <<'EOF'
        cmake_minimum_required(VERSION 3.20)
        project(highway_consumer LANGUAGES CXX)
        find_package(hwy ${package.version} CONFIG REQUIRED)
        add_executable(consumer consumer.cc)
        target_compile_features(consumer PRIVATE cxx_std_17)
        target_link_libraries(consumer PRIVATE hwy::hwy_contrib hwy::hwy_test hwy::hwy)
        EOF
        cmake -S . -B build -G Ninja -DCMAKE_MAKE_PROGRAM=${tools.ninja}/bin/ninja \
          -DCMAKE_PREFIX_PATH="${package}" >&2
        cmake --build build --parallel "$NIX_BUILD_CORES" >&2
        ./build/consumer
      '';
      expected = "Highway dispatch";
    };
  };
}
