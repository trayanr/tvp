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
in
{
  pname = "libsodium";
  inherit base src version;
  inherit (tools) bash coreutils;
  environment.tools = [
    tools.gnumake
    tools.sed
    tools.grep
    tools.gawk
    tools.diffutils
    tools.findutils
  ];
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (steps.prepareAutotools { name = "libsodium.prepare"; })
    (command "libsodium.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash
      ./configure --prefix="$out" --libdir="$out/lib" --enable-shared --disable-static
    '')
    (command "libsodium.build" make)
    (command "libsodium.install" "${make} install")
    (steps.split "libsodium.finalize")
    (outputs.copyArtifacts { })
    (outputs.relocateText {
      paths = [
        "lib/libsodium.la"
        "lib/pkgconfig/libsodium.pc"
      ];
    })
    (outputs.strip { paths = [ "lib" ]; })
    (outputs.rpaths {
      paths = [ "lib" ];
      libraries = final.runtime.libraries;
    })
    (outputs.checkPaths { paths = [ "lib" ]; })
  ];
  meta = {
    description = "Cryptographic primitives for encryption, signatures and hashing";
    homepage = "https://doc.libsodium.org/";
    license = lib.licenses.isc;
    platforms = [ "x86_64-linux" ];
  };
}
