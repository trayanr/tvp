# Only the opt-in variant adds these controls; canonical test identities stay fixed.
{
  pkgs,
  tvpLib,
  package,
  cmake,
}:
let
  steps = import ../../../../lib/build-steps.nix;
  edited = package.withBuildSteps {
    doCheck = false;
    editSteps =
      plan:
      steps.insertAfter "json-c.build"
        [
          {
            name = "probe.between";
            run = ''
              test -f build/libjson-c.a
              test ! -e "$out"
              printf 'build\nbetween\n' > edit-order
              echo 'named insertion between build and install' >&2
            '';
          }
        ]
        (
          steps.replace "json-c.install"
            (
              old:
              old
              // {
                run =
                  old.run
                  + "\n"
                  + ''
                    printf 'install\n' >> edit-order
                    diff -u <(printf 'build\nbetween\ninstall\n') edit-order
                  '';
              }
            )
            (
              steps.replace "json-c.check" (
                old:
                old
                // {
                  tools = throw "disabled check tools were forced";
                  run = throw "disabled check body was forced";
                }
              ) plan
            )
        );
  };
in
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    cmake-consumer = {
      extraInputs = [
        package.tvp.cc
        cmake
        package.tvp.deps.gnumake
      ];
      script = ''
        set -euo pipefail
        mkdir consumer
        cat > consumer/CMakeLists.txt <<'CMAKE'
        cmake_minimum_required(VERSION 3.16)
        project(json_c_consumer C)
        find_package(json-c CONFIG REQUIRED NO_DEFAULT_PATH PATHS "${package}/lib/cmake/json-c")
        add_executable(shared ${./fixtures/api.c})
        target_link_libraries(shared PRIVATE json-c::json-c)
        add_executable(archive ${./fixtures/api.c})
        target_link_libraries(archive PRIVATE json-c::json-c-static m)
        CMAKE
        cmake -S consumer -B consumer-build -G 'Unix Makefiles' >&2
        cmake --build consumer-build --parallel "$NIX_BUILD_CORES" >&2
        test "$(consumer-build/shared)" = ok
        test "$(consumer-build/archive)" = ok
        echo ok
      '';
      expected = "ok";
    };
    named-edits = {
      script = ''
        set -euo pipefail
        test -f ${edited}/lib/libjson-c.a
        test -f ${edited}/include/json-c/json_patch.h
        echo ok
      '';
      expected = "ok";
    };
  };
}
