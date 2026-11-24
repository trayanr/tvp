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
  paths = [ "lib" ];
in
{
  pname = "libuuid";
  inherit base src version;
  inherit (tools) bash coreutils;
  environment.tools = [
    tools.gnumake
    tools.gawk
    tools.grep
    tools.sed
    tools.pkg-config
  ];
  runtime.libraries = [ ];
  plan = [
    (steps.unpack { src = final.src; compression = "xz"; })
    (steps.prepareAutotools { name = "libuuid.prepare"; })
    (command "libuuid.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash
      "$CONFIG_SHELL" ./configure --prefix="$out" --libdir="$out/lib" \
        --disable-all-programs --enable-libuuid --disable-static --disable-asciidoc \
        --disable-nls --without-python --without-systemd
    '')
    (command "libuuid.build" "${make} all")
    (command "libuuid.install" ''
      ${make} install
      install -Dm644 Documentation/licenses/COPYING.BSD-3-Clause \
        "$out/share/licenses/libuuid/COPYING"
      test -f "$out/include/uuid/uuid.h"
      test -f "$out/lib/pkgconfig/uuid.pc"
      test -e "$out/lib/libuuid.so"
    '')
    (steps.split "libuuid.finalize")
    (outputs.copyArtifacts { })
    (outputs.libtool { paths = [ "lib" ]; })
    (outputs.relocateText { paths = [ "lib/pkgconfig" ]; })
    (outputs.strip { inherit paths; })
    (outputs.rpaths { inherit paths; libraries = final.runtime.libraries; })
    (outputs.checkPaths { inherit paths; })
  ];
  meta = {
    description = "UUID generation and parsing library from util-linux";
    homepage = "https://www.kernel.org/pub/linux/utils/util-linux/";
    license = lib.licenses.bsd3;
  };
}
