{
  tvp,
  lib,
  base,
  src,
  version,
  bison,
  flex,
  gdbm,
  gettext,
  libxcrypt,
  meson,
  ninja,
  openssl,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = steps.command { environment = final.environment; };
  paths = [
    "sbin"
    "lib"
  ];
in
{
  pname = "libpam";
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    bison
    flex
    gdbm
    gettext
    libxcrypt
    meson
    ninja
    openssl
    ;
  inherit (tools) bash coreutils;
  environment = {
    tools = [
      final.bison
      final.flex
      final.gettext
      final.meson
      final.ninja
    ];
    libraries = final.runtime.libraries;
  };
  runtime.libraries = [
    final.gdbm
    final.libxcrypt
    final.openssl
  ];
  plan = [
    (steps.unpack {
      src = final.src;
      compression = "xz";
    })
    (steps.shebangs {
      name = "libpam.prepare-shell";
      paths = [ "aux" ];
      names = [ "sh" ];
      interpreter = "${tools.bash}/bin/bash";
    })
    (command "libpam.configure" ''
      export NINJA=${final.ninja}/bin/ninja
      # These optional integrations require additional source-owned providers.
      "${final.meson}/bin/meson" setup build . --prefix="$out" --libdir=lib \
        --buildtype=release --wrap-mode=nodownload \
        -Dsecuredir="$out/lib/security" -Dvendordir="$out/share/pam" \
        -Di18n=enabled -Dopenssl=enabled -Dpam_unix=enabled -Dpam_userdb=enabled -Ddb=gdbm \
        -Ddocs=disabled -Daudit=disabled -Deconf=disabled -Dlogind=disabled \
        -Delogind=disabled -Dpwaccess=disabled -Dselinux=disabled -Dnis=disabled
    '')
    (command "libpam.build" ''"${final.meson}/bin/meson" compile -C build -j "$NIX_BUILD_CORES"'')
    (command "libpam.install" ''
      "${final.meson}/bin/meson" install -C build --no-rebuild
      install -Dm644 COPYING "$out/share/licenses/libpam/COPYING"
      install -Dm644 Copyright "$out/share/licenses/libpam/Copyright"
      test -f "$out/include/security/pam_appl.h"
      test -f "$out/lib/pkgconfig/pam.pc"
      test -f "$out/lib/security/pam_unix.so"
      test -f "$out/lib/security/pam_userdb.so"
    '')
    (steps.split "libpam.finalize")
    (outputs.copyArtifacts { })
    {
      name = "libpam.relocate";
      tools = [ tools.python ];
      run = ''"${tools.python}/bin/python3" -B ${../jdk-support-relocate.py} "$out" "$TVP_ARTIFACT_ROOT"'';
    }
    (outputs.shebangs {
      paths = [
        "sbin"
        "share/pam"
      ];
      names = [
        "sh"
        "bash"
      ];
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
    description = "Linux Pluggable Authentication Modules and developer interfaces";
    homepage = "https://github.com/linux-pam/linux-pam";
    license = [
      lib.licenses.bsd3
      lib.licenses.gpl2Plus
    ];
  };
}
