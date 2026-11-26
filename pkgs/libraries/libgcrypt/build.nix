{
  tvp,
  lib,
  base,
  src,
  version,
  libgpg-error,
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
  pname = "libgcrypt";
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    libgpg-error
    texinfo
    ;
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
      final.libgpg-error
      final.texinfo
    ];
    libraries = [ final.libgpg-error ];
  };
  runtime.libraries = [ final.libgpg-error ];
  plan = [
    (steps.unpack {
      src = final.src;
      compression = "bzip2";
    })
    (steps.prepareAutotools { name = "libgcrypt.prepare"; })
    (command "libgcrypt.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash
      export GPGRT_CONFIG=${final.libgpg-error}/bin/gpgrt-config
      "$CONFIG_SHELL" ./configure --prefix="$out" --libdir="$out/lib" \
        --enable-shared --enable-static --enable-doc \
        --with-libgpg-error-prefix=${final.libgpg-error}
    '')
    (command "libgcrypt.build" make)
    (command "libgcrypt.install" ''
      ${make} install
      # Older libxslt configure scripts still consume this upstream helper.
      install -Dm755 src/libgcrypt-config "$out/bin/libgcrypt-config"
      install -Dm644 COPYING "$out/share/licenses/libgcrypt/COPYING"
      install -Dm644 COPYING.LIB "$out/share/licenses/libgcrypt/COPYING.LIB"
      test -f "$out/lib/pkgconfig/libgcrypt.pc"
    '')
    (steps.split "libgcrypt.finalize")
    (outputs.copyArtifacts { })
    {
      name = "libgcrypt.relocate";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../jdk-support-relocate.py} "$out" "$TVP_ARTIFACT_ROOT"'';
    }
    (outputs.shebangs {
      paths = [ "bin/libgcrypt-config" ];
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
    (outputs.development { libraries = final.runtime.libraries; })
    (outputs.checkPaths {
      inherit paths;
      elfKinds = [ "runtime" ];
    })
  ];
  meta = {
    description = "General-purpose cryptographic library from the GnuPG project";
    homepage = "https://gnupg.org/software/libgcrypt/index.html";
    license = [
      lib.licenses.lgpl21Plus
      lib.licenses.gpl2Plus
    ];
  };
}
