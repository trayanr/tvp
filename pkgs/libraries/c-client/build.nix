{
  tvp,
  lib,
  base,
  src,
  version,
  openssl,
  patches ? [ ],
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = steps.command { environment = final.environment; };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'';
in
{
  pname = "c-client";
  inherit
    base
    src
    version
    openssl
    patches
    ;
  inherit (tools) bash coreutils;
  environment = {
    libraries = [ final.openssl ];
    tools = [
      tools.gnumake
    ];
  };
  # The output is a static PIC archive. Consumers select their link providers.
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (steps.command { environment.tools = [ tools.patch ]; } "c-client.patch" ''
      for patch in ${lib.escapeShellArgs (map (file: "${file}") final.patches)}; do
        ${tools.patch}/bin/patch --batch --fuzz=0 -p1 < "$patch"
      done
    '')
    (steps.shebangs {
      name = "c-client.prepare-scripts";
      paths = [
        "tools/an"
        "src/osdep/unix/drivers"
        "src/osdep/unix/mkauths"
      ];
      names = [ "sh" ];
      interpreter = "${tools.bash}/bin/bash";
    })
    (command "c-client.prepare" ''
      ${make} SH=${tools.bash}/bin/bash an
    '')
    (command "c-client.build" ''
      ${make} -C c-client slx IP=6 SSLTYPE=nopwd \
        CC=cc EXTRACFLAGS="-std=gnu89 -fPIC" \
        SSLINCLUDE=${lib.escapeShellArg "${lib.getDev final.openssl}/include"}
    '')
    (command "c-client.install" ''
      mkdir -p "$out/include/c-client" "$out/lib"
      cp c-client/*.h c-client/linkage.c c-client/auths.c "$out/include/c-client/"
      cp c-client/c-client.a "$out/lib/libc-client.a"
    '')
    (steps.split "c-client.finalize")
    (outputs.copyArtifacts { })
  ];
  meta = {
    description = "UW IMAP c-client mail access library";
    homepage = "https://github.com/uw-imap/imap";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
  };
}
