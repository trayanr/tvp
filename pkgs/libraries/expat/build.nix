# Complete Expat 2.9.0 CMake/Ninja procedure; upstream policy starts after A.
{
  tvp,
  lib,
  base,
  src,
  version,
  doCheck ? true,
  cmakeFlags ? [ ],
  buildFeatures ? { },
  sourceLayout ? { },
  installedInterface ? { },
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  environment = final.base.environment final.environment;
  command = steps.command {
    environment = final.environment;
  };
  checkpoint = "nix-support/expat-build-tree";
  onOff = value: if value then "ON" else "OFF";
  productionFlags =
    assert
      !(builtins.any (flag: lib.hasPrefix "-DEXPAT_BUILD_TESTS" flag) final.cmakeFlags)
      || throw "Expat: configure upstream tests through upstreamPolicy, not production cmakeFlags";
    [
      "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
      "-DCMAKE_INSTALL_LIBDIR=lib"
      "-DCMAKE_BUILD_TYPE=Release"
      "-DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF"
      "-DCMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY=OFF"
      "-DEXPAT_BUILD_DOCS=${onOff final.buildFeatures.docs}"
      "-DEXPAT_SHARED_LIBS=${onOff final.buildFeatures.shared}"
      "-DEXPAT_BUILD_TOOLS=${onOff final.buildFeatures.tools}"
      "-DEXPAT_BUILD_EXAMPLES=${onOff final.buildFeatures.examples}"
    ]
    ++ final.cmakeFlags
    ++ [ "-DEXPAT_BUILD_TESTS=OFF" ];
in
{
  pname = "expat";
  inherit
    base
    src
    version
    doCheck
    cmakeFlags
    ;
  inherit (tools) bash coreutils;
  buildFeatures = {
    docs = false;
    shared = true;
    tools = true;
    examples = true;
  } // buildFeatures;
  # Keep the compiled CMake tree under source, so the shared checkpoint helper
  # saves it and restores the exact original absolute build location.
  sourceLayout = {
    compression = "xz";
    buildDirectory = ".tvp-build";
  } // sourceLayout;
  installedInterface = {
    elfPaths = lib.optional final.buildFeatures.tools "bin" ++ [ "lib" ];
    relocatedText = [
      "lib/pkgconfig"
      "lib/cmake"
    ];
    soname = "libexpat.so.1";
  } // installedInterface;
  environment = {
    tools = [
      tools.cmake
      tools.ninja
    ];
    libraries = [ ];
  };
  runtime.libraries = [ ];
  development = {
    includeDirectories = [ "include" ];
    libraries = [ ];
  };
  productionPlan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = final.sourceLayout.compression;
    })
    (command "expat.configure" ''
      ${tools.cmake}/bin/cmake -S . -B ${lib.escapeShellArg final.sourceLayout.buildDirectory} -G Ninja \
        -DCMAKE_MAKE_PROGRAM=${tools.ninja}/bin/ninja -DCMAKE_INSTALL_PREFIX="$out" \
        -DCMAKE_INSTALL_RPATH="$out/lib" ${lib.escapeShellArgs productionFlags}
    '')
    (command "expat.build" ''${tools.cmake}/bin/cmake --build ${lib.escapeShellArg final.sourceLayout.buildDirectory} --parallel "$NIX_BUILD_CORES" --verbose'')
    (command "expat.install" ''
      ${tools.cmake}/bin/cmake --install ${lib.escapeShellArg final.sourceLayout.buildDirectory}
      mkdir -p "$out/share/licenses/expat" "$out/nix-support"
      cp COPYING "$out/share/licenses/expat/"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    (
      (command "expat.save-build-tree" ''
        ${tools.python}/bin/python3 -B ${../../../lib/build-checkpoint.py} "$TVP_SOURCE_ROOT" "$out/${checkpoint}"
      '')
      // {
        tools = environment.tools ++ [ tools.python ];
      }
    )
  ];
  upstreamPolicy = {
    cmakeFlags = [ "-DEXPAT_BUILD_TESTS=ON" ];
    ctestFlags = [
      "--output-on-failure"
      "--no-tests=error"
    ];
  };
  upstreamPlan = artifact: [
    (steps.restoreCheckpoint {
      name = "expat.restore-build-tree";
      checkpoint = "${artifact}/${checkpoint}";
    })
    (
      (command "expat.configure-upstream" ''
        cd "$(cat "$TVP_SOURCE_ROOT/tree-path")"
        ${tools.cmake}/bin/cmake -S . -B ${lib.escapeShellArg final.sourceLayout.buildDirectory} \
          ${lib.escapeShellArgs final.upstreamPolicy.cmakeFlags}
      '')
      // {
        cwd = ".";
      }
    )
    (
      (command "expat.build-upstream" ''
        cd "$(cat "$TVP_SOURCE_ROOT/tree-path")"
        ${tools.cmake}/bin/cmake --build ${lib.escapeShellArg final.sourceLayout.buildDirectory} --parallel "$NIX_BUILD_CORES" --verbose
      '')
      // {
        cwd = ".";
      }
    )
  ];
  upstreamCheck =
    (command "expat.check" ''
      ${tools.cmake}/bin/ctest --test-dir ${lib.escapeShellArg final.sourceLayout.buildDirectory} \
        ${lib.escapeShellArgs final.upstreamPolicy.ctestFlags} -j "$NIX_BUILD_CORES"
    '')
    // {
      enabled = final.doCheck;
    };
  plan = final.productionPlan ++ [
    (steps.split "expat.finalize")
    (outputs.copyArtifacts { })
    {
      name = "expat.drop-build-tree";
      tools = [ tools.coreutils ];
      run = ''${tools.coreutils}/bin/rm -rf -- "$out/${checkpoint}"'';
    }
    (outputs.relocateText { paths = final.installedInterface.relocatedText; })
    (outputs.strip { paths = final.installedInterface.elfPaths; })
    (outputs.rpaths {
      paths = final.installedInterface.elfPaths;
      libraries = final.runtime.libraries;
      dlopenDirectories = final.runtime.dlopenDirectories or [ ];
    })
    (outputs.development { libraries = final.development.libraries; })
    (outputs.checkPaths { paths = final.installedInterface.elfPaths; })
  ];
  tvp.features = {
    doCheck = final.upstreamCheck.enabled;
    shared = final.buildFeatures.shared;
    static = !final.buildFeatures.shared;
  };
  meta = {
    description = "Streaming XML parser library and xmlwf tool";
    homepage = "https://libexpat.github.io/";
    license = lib.licenses.mit;
  };
}
