{
  tvp,
  lib,
  base,
  src,
  version,
  shared ? true,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  environment = final.base.environment final.environment;
  paths = [ "lib" ];
  oldAssembler = lib.versionOlder (lib.getVersion final.base.compiler.bintools) "2.44";
in
{
  pname = "highway";
  inherit
    base
    src
    version
    ;
  inherit (tools) bash coreutils;
  buildFeatures = { inherit shared; };
  environment.tools = [ tools.cmake ];
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (lib.optional oldAssembler (
      steps.command
        {
          environment.tools = [
            tools.grep
            tools.sed
          ];
        }
        "highway.avx10-assembler"
        ''
          # Upstream's AVX10.2 blocklist checks GCC but also requires GNU as 2.44.
          # Keep the restriction in the installed header for downstream dispatch.
          probe='#if (HWY_COMPILER_CLANG < 2300) && (HWY_COMPILER_GCC_ACTUAL < 1502)'
          test "$(grep -Fxc "$probe" hwy/detect_targets.h)" -eq 1
          sed -i "s|^$probe\$|#if 1  // Selected GNU assembler predates AVX10.2.|" hwy/detect_targets.h
        ''
    ))
    (steps.cmake {
      name = "highway";
      inherit (environment) tools libraries env;
      inherit (tools) cmake;
      make = tools.gnumake;
      doCheck = false;
      cmakeFlags = [
        "-DBUILD_SHARED_LIBS=${if final.buildFeatures.shared then "ON" else "OFF"}"
        "-DHWY_ENABLE_CONTRIB=ON"
        "-DHWY_ENABLE_INSTALL=ON"
        # Install the test-support library from the archive without running
        # the full suite or fetching GoogleTest during CMake configuration.
        "-DHWY_ENABLE_TESTS=ON"
        "-DHWY_TEST_STANDALONE=ON"
        "-DBUILD_TESTING=OFF"
        "-DHWY_ENABLE_EXAMPLES=OFF"
      ];
    })
    (steps.command { environment = final.environment; } "highway.license" ''
      install -Dm644 LICENSE "$out/share/licenses/highway/LICENSE"
    '')
    (steps.split "highway.finalize")
    (outputs.copyArtifacts { })
    (outputs.relocateText {
      paths = [
        "lib/cmake"
        "lib/pkgconfig"
      ];
    })
    (outputs.strip {
      inherit paths;
      elfKinds = [ "runtime" ];
    })
    (lib.optional (!final.buildFeatures.shared) (outputs.stripArchives { inherit paths; }))
    (outputs.rpaths {
      inherit paths;
      libraries = final.runtime.libraries;
      elfKinds = [ "runtime" ];
    })
    (lib.optional final.buildFeatures.shared {
      name = "highway.self-runtime";
      tools = [
        tools.binutils
        tools.patchelf
        tools.python
      ];
      # The contrib and test libraries both load the sibling libhwy.
      run = ''${tools.python}/bin/python3 -B ${../../../lib/append-self-rpaths.py} "$out" ${
        lib.escapeShellArg (
          builtins.toJSON {
            inherit paths;
            directories = paths;
            readelf = "${tools.binutils}/bin/readelf";
            patchelf = "${tools.patchelf}/bin/patchelf";
          }
        )
      } ${../../../lib/native-output}'';
    })
    (outputs.checkPaths {
      inherit paths;
      elfKinds = [ "runtime" ];
    })
  ];
  meta = {
    description = "Portable SIMD library with runtime dispatch";
    homepage = "https://github.com/google/highway";
    license = with lib.licenses; [
      asl20
      bsd3
      cc0
    ];
    platforms = [ "x86_64-linux" ];
  };
}
