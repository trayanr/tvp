{
  tvp,
  lib,
  base,
  src,
  version,
  jpeg,
  zlib,
  lcms2 ? null,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = steps.command { environment = final.environment; };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'';
  libraries = [ final.jpeg final.zlib ] ++ lib.optional (final.lcms2 != null) final.lcms2;
  paths = [ "bin" "lib" ];
in
{
  pname = "libraw";
  inherit base src version jpeg zlib lcms2;
  inherit (tools) bash coreutils;
  environment = {
    tools = [
      tools.gnumake
      tools.gawk
      tools.grep
      tools.sed
      tools.diffutils
      tools.findutils
      tools.pkg-config
    ];
    inherit libraries;
  };
  runtime.libraries = libraries;
  tvp.features = {
    jpeg = true;
    zlib = true;
    openmp = true;
    lcms = final.lcms2 != null;
  };
  plan = [
    (steps.unpack { src = final.src; compression = "gzip"; })
    (steps.prepareAutotools { name = "libraw.prepare"; })
    (command "libraw.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash
      # Both decoders ship in the release archive as opt-in code.
      export CPPFLAGS="-DUSE_X3FTOOLS -DUSE_6BY9RPI ''${CPPFLAGS:-}"
      "$CONFIG_SHELL" ./configure --prefix="$out" --libdir="$out/lib" \
        --enable-shared --enable-static --enable-openmp --enable-jpeg --enable-zlib \
        --enable-examples ${if final.lcms2 == null then "--disable-lcms" else "--enable-lcms"}
      ${lib.optionalString (final.lcms2 != null) ''
        # The LCMS2 check replaces configure's zlib entry in PACKAGE_REQUIRES.
        for file in libraw.pc libraw_r.pc; do
          test "$(grep -Fxc 'Requires: lcms2' "$file")" = 1
          sed -i 's/^Requires: lcms2$/Requires: zlib lcms2/' "$file"
        done
      ''}
    '')
    (command "libraw.build" make)
    (command "libraw.install" ''
      ${make} install
      test -f "$out/include/libraw/libraw.h"
      test -e "$out/lib/libraw.so"
      test -e "$out/lib/libraw_r.so"
      test -f "$out/lib/pkgconfig/libraw_r.pc"
      test -x "$out/bin/raw-identify"
    '')
    (steps.split "libraw.finalize")
    (outputs.copyArtifacts { })
    (outputs.libtool { paths = [ "lib" ]; })
    (outputs.relocateText { paths = [ "lib/pkgconfig" ]; })
    (outputs.strip { inherit paths; elfKinds = [ "runtime" ]; })
    (outputs.stripArchives { paths = [ "lib" ]; })
    (outputs.rpaths { inherit paths; libraries = final.runtime.libraries; elfKinds = [ "runtime" ]; })
    (outputs.development { libraries = final.runtime.libraries; })
    (outputs.checkPaths { inherit paths; elfKinds = [ "runtime" ]; })
  ];
  meta = {
    description = "Camera RAW image decoding libraries and tools";
    homepage = "https://www.libraw.org/";
    mainProgram = "raw-identify";
    license = [ lib.licenses.lgpl21Only lib.licenses.cddl ];
    platforms = [ "x86_64-linux" ];
  };
}
