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
  command = steps.command { environment = final.environment; };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'';
  paths = [ "bin" "lib" ];
in
{
  pname = "lz4";
  inherit base src version;
  inherit (tools) bash coreutils;
  environment.tools = [ tools.gnumake tools.sed tools.grep tools.findutils ];
  runtime.libraries = [ ];
  plan = [
    (steps.unpack { src = final.src; compression = "gzip"; })
    (command "lz4.build" ''${make} default'')
    (command "lz4.install" ''
      ${make} PREFIX="$out" LIBDIR="$out/lib" install
      install -Dm644 lib/LICENSE "$out/share/licenses/lz4/lib/LICENSE"
      install -Dm644 programs/COPYING "$out/share/licenses/lz4/programs/COPYING"
      test -x "$out/bin/lz4"
      test -f "$out/lib/pkgconfig/liblz4.pc"
      test -f "$out/include/lz4.h"
    '')
    (steps.split "lz4.finalize")
    (outputs.copyArtifacts { })
    (outputs.relocateText { paths = [ "lib/pkgconfig" ]; })
    (outputs.strip { inherit paths; elfKinds = [ "runtime" ]; })
    (outputs.rpaths { inherit paths; libraries = final.runtime.libraries; elfKinds = [ "runtime" ]; })
    (outputs.checkPaths { inherit paths; elfKinds = [ "runtime" ]; })
  ];
  meta = {
    description = "LZ4 compression library and command-line tools";
    homepage = "https://lz4.org/";
    mainProgram = "lz4";
    license = [ lib.licenses.bsd2 lib.licenses.gpl2Plus ];
  };
}
