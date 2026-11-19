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
  pname = "oniguruma";
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
    (steps.prepareAutotools { name = "oniguruma.prepare"; })
    (command "oniguruma.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash
      ./configure --prefix="$out" --libdir="$out/lib" --enable-shared --disable-static
    '')
    (command "oniguruma.build" make)
    (command "oniguruma.install" ''
      ${make} install
      install -Dm644 COPYING "$out/share/licenses/oniguruma/COPYING"
    '')
    (steps.split "oniguruma.finalize")
    (outputs.copyArtifacts { })
    (outputs.relocateText {
      paths = [
        "bin/onig-config"
        "lib/libonig.la"
        "lib/pkgconfig/oniguruma.pc"
      ];
    })
    (outputs.shebangs {
      paths = [ "bin/onig-config" ];
      names = [ "sh" ];
      interpreter = "${tools.bash}/bin/bash";
    })
    (command "oniguruma.bind-config-tools" ''
      ${tools.sed}/bin/sed -i '2i export PATH=${tools.sed}/bin:${tools.coreutils}/bin' "$out/bin/onig-config"
    '')
    (outputs.strip { paths = [ "lib" ]; })
    (outputs.rpaths {
      paths = [ "lib" ];
      libraries = final.runtime.libraries;
    })
    (outputs.checkSymlinks {
      paths = [
        "lib/libonig.so"
        "lib/libonig.so.5"
      ];
    })
    (outputs.checkPaths { paths = [ "lib" ]; })
  ];
  meta = {
    description = "Multibyte regular expression library";
    homepage = "https://github.com/kkos/oniguruma";
    license = lib.licenses.bsd2;
    platforms = [ "x86_64-linux" ];
  };
}
