{
  tvp,
  lib,
  base,
  src,
  version,
  glib,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = steps.command { environment = final.environment; };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'';
in
{
  pname = "liblqr";
  inherit
    base
    src
    version
    glib
    ;
  inherit (tools) bash coreutils;
  outputs = [ "out" ];
  environment = {
    tools = with tools; [
      gnumake
      gawk
      grep
      sed
      diffutils
      findutils
      pkg-config
    ];
    libraries = [ final.glib ] ++ final.glib.specification.environment.libraries;
  };
  runtime.libraries = [ final.glib ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "bzip2";
    })
    (steps.prepareAutotools { name = "liblqr.prepare"; })
    (command "liblqr.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash
      # liblqr 0.4.3 still declares some functions with C17 prototypes.
      export CFLAGS="''${CFLAGS:--O2} -std=gnu17"
      "$CONFIG_SHELL" ./configure --prefix="$out" --libdir="$out/lib" --enable-shared --disable-static --enable-install-man
    '')
    (command "liblqr.build" make)
    (command "liblqr.install" "${make} install")
    (steps.split "liblqr.finalize")
    (outputs.copyArtifacts { outputs = final.outputs; })
    (outputs.libtool { paths = [ "lib" ]; })
    (outputs.relocateText { paths = [ "lib/pkgconfig" ]; })
    {
      name = "liblqr.pkg-config-library-directory";
      tools = [
        tools.grep
        tools.sed
      ];
      run = ''
        file="$out/lib/pkgconfig/lqr-1.pc"
        test "$(grep -Fxc 'Libs: -llqr-1' "$file")" = 1
        sed -i 's/^Libs: -llqr-1$/Libs: -L''${libdir} -llqr-1/' "$file"
      '';
    }
    (outputs.strip { paths = [ "lib" ]; })
    (outputs.rpaths {
      paths = [ "lib" ];
      libraries = final.runtime.libraries;
    })
    (outputs.development { libraries = final.environment.libraries; })
    (outputs.checkPaths { paths = [ "lib" ]; })
  ];
  meta = {
    description = "Seam carving library for content-aware image resizing";
    homepage = "https://liblqr.wikidot.com/";
    license = lib.licenses.lgpl3Only;
    platforms = [ "x86_64-linux" ];
  };
}
