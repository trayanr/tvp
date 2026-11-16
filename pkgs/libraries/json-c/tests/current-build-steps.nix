{
  package,
  lib,
  context,
}:

let
  mkSuite =
    args:
    context.mkSuite {
      inherit package;
      libraries = [ package ];
      tests = builtins.mapAttrs (
        _: test:
        (builtins.removeAttrs test [ "extraInputs" ])
        // {
          tools =
            (test.tools or [ ])
            ++ (test.extraInputs or [ ])
            ++ [
              package.specification.gawk or package.specification.base.tools.gawk
              package.specification.grep or package.specification.base.tools.grep
              package.specification.sed or package.specification.base.tools.sed
            ];
        }
      ) args.tests;
    };
  steps = import ../../../../lib/build-steps.nix;
  disabledPolicy = (package.override { doCheck = false; }).edit (
    old:
    old
    // {
      upstreamCheck = old.upstreamCheck // {
        tools = throw "disabled check tools were forced by A/F";
        run = throw "disabled check run was forced by A/F";
      };
    }
  );
  edited = (package.override { doCheck = false; }).editSteps (
    plan:
    let
      withoutCheck = plan;
      checkedInstall = steps.replace "json-c.install" (
        old:
        old
        // {
          run =
            old.run
            + "\n"
            + ''
              printf 'install\n' >> edit-order
              ${
                if package ? testContext then "${package.tvp.declaredTestDependencies.diffutils}/bin/" else ""
              }diff -u <(printf 'build\nbetween\ninstall\n') edit-order
            '';
        }
      ) withoutCheck;
      logged = steps.insertAfter "json-c.build" [
        {
          name = "probe.between";
          run = ''
            test -f build/libjson-c.a
            test ! -e "$out"
            printf 'build\nbetween\n' > edit-order
            echo 'named insertion between build and install' >&2
          '';
        }
      ] checkedInstall;
    in
    steps.insertBefore "source.unpack" [
      {
        name = "probe.before-source";
        run = ''
          test ! -e source-date-epoch
          echo 'named insertion before source preparation' >&2
        '';
      }
    ] logged
  );
  cmake = package.tvp.declaredTestDependencies.cmake;
  environment = package.specification.base.environment {
    tools = [
      cmake
      package.specification.gnumake
    ];
    libraries = [ package ];
  };

in
assert disabledPolicy.artifact.drvPath == package.artifact.drvPath;
assert disabledPolicy.drvPath == package.drvPath;
mkSuite {
  inherit package;
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
        find_package(json-c CONFIG REQUIRED)
        add_executable(shared ${./fixtures/api.c})
        target_link_libraries(shared PRIVATE json-c::json-c)
        add_executable(archive ${./fixtures/api.c})
        target_link_libraries(archive PRIVATE json-c::json-c-static m)
        CMAKE
        export CMAKE_PREFIX_PATH=${lib.escapeShellArg environment.env.CMAKE_PREFIX_PATH}
        ${cmake}/bin/cmake -S consumer -B consumer-build -G 'Unix Makefiles' -DCMAKE_MAKE_PROGRAM=${package.tvp.deps.gnumake}/bin/make -DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF -DCMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY=OFF >&2
        ${cmake}/bin/cmake --build consumer-build --parallel "$NIX_BUILD_CORES" >&2
        test "$(env -i consumer-build/shared)" = ok
        env -i LD_DEBUG=libs consumer-build/shared > /dev/null 2> loader
        grep -F 'calling init: ${package}/lib/libjson-c.so.5' loader >&2
        test "$(env -i consumer-build/archive)" = ok
        echo ok
      '';
      expected = "ok";
    };
    named-edits = {
      # Composition must retain the metadata needed to evaluate family tests.
      script =
        assert builtins.all (name: builtins.isString edited.tests.${name}.drvPath) [
          "public-api"
          "static-api"
          "pkgconfig"
          "installed-features"
          "upstream-tags"
        ];
        assert edited.tvp.upstream.normalise "json-c-0.19-20260627" == "0.19";
        assert edited.tests.pkgconfig.drvPath != package.tests.pkgconfig.drvPath;
        ''
          set -euo pipefail
          test -f ${edited}/lib/libjson-c.a
          test -f ${edited}/include/json-c/json_patch.h
          prefix=$(PKG_CONFIG_LIBDIR=${edited}/lib/pkgconfig \
            ${edited.tvp.declaredTestDependencies.pkg-config}/bin/pkg-config --variable=prefix json-c)
          test "$prefix" = ${edited}
          echo ok
        '';
      expected = "ok";
    };
  };
}
