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
