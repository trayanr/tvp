{
  tvp,
  lib,
  base,
  src,
  version,
  jpeg,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = steps.command { environment = final.environment; };
  cmake = "${tools.cmake}/bin/cmake";
  paths = [
    "bin"
    "lib"
  ];
in
{
  pname = "libultrahdr";
  inherit base src version jpeg;
  inherit (tools) bash coreutils;
  environment = {
    tools = [ tools.cmake tools.ninja ];
    libraries = [ final.jpeg ];
  };
  runtime.libraries = final.environment.libraries;
  plan = [
    (steps.unpack { src = final.src; compression = "gzip"; })
    (command "libultrahdr.configure" ''
      ${cmake} -S . -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$out" -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_MAKE_PROGRAM=${tools.ninja}/bin/ninja -DCMAKE_PREFIX_PATH=${final.jpeg} \
        -DBUILD_SHARED_LIBS=ON -DUHDR_BUILD_DEPS=OFF -DUHDR_BUILD_EXAMPLES=ON \
        -DUHDR_ENABLE_INTRINSICS=ON -DUHDR_ENABLE_HEIF=OFF
    '')
    (command "libultrahdr.build" ''${cmake} --build build --parallel "$NIX_BUILD_CORES"'')
    (command "libultrahdr.install" ''
      ${cmake} --install build
      install -Dm644 LICENSE "$out/share/licenses/libultrahdr/LICENSE"
      test -x "$out/bin/ultrahdr_app"
      test -f "$out/include/ultrahdr_api.h"
      test -f "$out/lib/pkgconfig/libuhdr.pc"
    '')
    (steps.split "libultrahdr.finalize")
    (outputs.copyArtifacts { })
    (outputs.relocateText { paths = [ "lib/pkgconfig" ]; })
    (outputs.strip { inherit paths; elfKinds = [ "runtime" ]; })
    (outputs.rpaths { inherit paths; libraries = final.runtime.libraries; elfKinds = [ "runtime" ]; })
    (outputs.development { libraries = final.runtime.libraries; })
    (outputs.checkPaths { inherit paths; elfKinds = [ "runtime" ]; })
  ];
  meta = {
    description = "Ultra HDR JPEG gain-map library and command-line tool";
    homepage = "https://github.com/google/libultrahdr";
    license = [ lib.licenses.mit lib.licenses.asl20 ];
    mainProgram = "ultrahdr_app";
  };
}
