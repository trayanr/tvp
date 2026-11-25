{
  tvp,
  lib,
  base,
  src,
  version,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  environment = final.base.environment final.environment;
  paths = [
    "bin"
    "lib"
  ];
in
{
  pname = "brotli";
  inherit
    base
    src
    version
    ;
  inherit (tools) bash coreutils;
  environment.tools = [ tools.cmake ];
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (steps.cmake {
      name = "brotli";
      inherit (environment) tools libraries env;
      inherit (tools) cmake;
      make = tools.gnumake;
      doCheck = false;
      cmakeFlags = [
        "-DBUILD_SHARED_LIBS=ON"
        "-DBROTLI_BUILD_FOR_PACKAGE=ON"
        "-DBROTLI_BUILD_TOOLS=ON"
        "-DBROTLI_DISABLE_TESTS=ON"
      ];
    })
    (steps.command { environment = final.environment; } "brotli.license" ''
      install -Dm644 LICENSE "$out/share/licenses/brotli/LICENSE"
    '')
    (steps.split "brotli.finalize")
    (outputs.copyArtifacts { })
    (outputs.relocateText { paths = [ "lib/pkgconfig" ]; })
    (outputs.strip {
      inherit paths;
      elfKinds = [ "runtime" ];
    })
    (outputs.stripArchives { paths = [ "lib" ]; })
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
    description = "Lossless Brotli compression format and command-line tool";
    homepage = "https://github.com/google/brotli";
    license = lib.licenses.mit;
    mainProgram = "brotli";
    platforms = [ "x86_64-linux" ];
  };
}
