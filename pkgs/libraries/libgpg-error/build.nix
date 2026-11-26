{
  tvp,
  lib,
  base,
  src,
  version,
  gettext,
  texinfo,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = steps.command { environment = final.environment; };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'';
  paths = [
    "bin"
    "lib"
  ];
in
{
  pname = "libgpg-error";
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    gettext
    texinfo
    ;
  inherit (tools) bash coreutils;
  environment.tools = [
    tools.gnumake
    tools.gawk
    tools.grep
    tools.sed
    tools.diffutils
    tools.findutils
    final.gettext
    final.texinfo
  ];
  runtime.libraries = [ ];
  plan = [
    (steps.unpack {
      src = final.src;
      compression = "bzip2";
    })
    (steps.prepareAutotools { name = "libgpg-error.prepare"; })
    (command "libgpg-error.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash
      "$CONFIG_SHELL" ./configure --prefix="$out" --libdir="$out/lib" \
        --enable-shared --enable-static --enable-nls --enable-doc \
        --enable-install-gpg-error-config --disable-tests
    '')
    (command "libgpg-error.build" make)
    (command "libgpg-error.install" ''
      ${make} install
      install -Dm644 COPYING "$out/share/licenses/libgpg-error/COPYING"
      install -Dm644 COPYING.LIB "$out/share/licenses/libgpg-error/COPYING.LIB"
      test -x "$out/bin/gpg-error-config"
      test -x "$out/bin/gpgrt-config"
      test -f "$out/lib/pkgconfig/gpg-error.pc"
    '')
    (steps.split "libgpg-error.finalize")
    (outputs.copyArtifacts { })
    {
      name = "libgpg-error.relocate";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../jdk-support-relocate.py} "$out" "$TVP_ARTIFACT_ROOT"'';
    }
    (outputs.shebangs {
      paths = [
        "bin/gpg-error-config"
        "bin/gpgrt-config"
      ];
      names = [ "sh" ];
      interpreter = "${tools.bash}/bin/bash";
    })
    (outputs.strip {
      inherit paths;
      elfKinds = [ "runtime" ];
    })
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
    description = "Common error values and runtime support for GnuPG libraries";
    homepage = "https://www.gnupg.org/software/libgpg-error/";
    license = [
      lib.licenses.lgpl21Plus
      lib.licenses.gpl2Plus
    ];
  };
}
