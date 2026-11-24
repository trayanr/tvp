{
  tvp,
  lib,
  base,
  src,
  version,
  libxml2,
  libgcrypt ? null,
  gnu-config ? null,
  compression,
  configureOptions ? [ ],
  patches ? [ ],
  license ? lib.licenses.mit,
  pkgconfig ? true,
  repairPkgconfigRequires ? false,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = steps.command { environment = final.environment; };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'';
  cryptoEnabled = final.libgcrypt != null;
  paths = [
    "bin"
    "lib"
  ];
in
{
  pname = "libxslt";
  inherit
    base
    src
    version
    libxml2
    libgcrypt
    gnu-config
    compression
    configureOptions
    patches
    license
    repairPkgconfigRequires
    ;
  inherit (tools) bash coreutils;
  artifactName = "${final.pname}-${final.version}";
  environment = {
    tools = [
      tools.gnumake
      final.libxml2
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
    ] ++ lib.optional cryptoEnabled final.libgcrypt;
    libraries = [ final.libxml2 ] ++ lib.optional cryptoEnabled final.libgcrypt;
    overrides.values.CFLAGS = "-O2 -std=gnu17 -fcommon";
  };
  runtime = {
    # xml2-config --libs links the selected libxml2 compression providers directly.
    libraries = [ final.libxml2 ] ++ final.libxml2.specification.runtime.libraries
      ++ lib.optional cryptoEnabled final.libgcrypt;
    shell = tools.bash;
  };
  installedInterface = { inherit pkgconfig; };
  tvp.features.crypto = cryptoEnabled;
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = final.compression;
    })
    (lib.optional (final.patches != [ ]) (
      steps.command { environment.tools = [ tools.patch ]; } "libxslt.patch" ''
        for patch in ${lib.escapeShellArgs (map (file: "${file}") final.patches)}; do
          ${tools.patch}/bin/patch --batch --fuzz=0 -p1 < "$patch"
        done
      ''
    ))
    (lib.optional (final.gnu-config != null) {
      name = "libxslt.gnu-config";
      cwd = "source";
      run = ''
        cp ${final.gnu-config}/config.guess ${final.gnu-config}/config.sub .
        chmod u+w config.guess config.sub
      '';
    })
    (steps.prepareAutotools { name = "libxslt.prepare"; })
    (command "libxslt.xml2-config-probe" ''
      # Newer xml2-config rejects the historical stray "print" argument.
      test "$(grep -c -- '--libs print' configure)" -eq 1
      sed -i 's/--libs print/--libs/g' configure
    '')
    (lib.optional (lib.versionOlder final.version "1.0.23") (
      command "libxslt.type-compiler-probe" ''
        # The shipped Autoconf probes relied on pre-C99 implicit int.
        test "$(grep -Fxc 'main(){return(0);}' configure)" -ge 1
        sed -i 's/^main(){return(0);}$/int main(void){return(0);}/' configure
      ''
    ))
    (lib.optional cryptoEnabled (
      command "libxslt.crypto-declaration" ''
        # The gcrypt code uses the C string API.
        if ! grep -Fqx '#include <string.h>' libexslt/crypto.c; then
          sed -i '1i #include <string.h>' libexslt/crypto.c
        fi
      ''
    ))
    (command "libxslt.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash
      export lt_cv_deplibs_check_method=pass_all
      ./configure --prefix="$out" --with-libxml-prefix=${final.libxml2} --disable-static \
        ${lib.escapeShellArgs (
          final.configureOptions ++ lib.optional (cryptoEnabled && final.version != "1.1.8") "--with-crypto"
        )}
      ${lib.optionalString cryptoEnabled "grep -Fxq '#define HAVE_GCRYPT 1' config.h"}
    '')
    (command "libxslt.build" make)
    (command "libxslt.install" ''
      ${make} install
      test -x "$out/bin/xsltproc"
      test -f "$out/include/libxslt/xslt.h"
      ${lib.optionalString final.installedInterface.pkgconfig ''test -f "$out/lib/pkgconfig/libxslt.pc"''}
    '')
    (steps.split "libxslt.finalize")
    (outputs.copyArtifacts { })
    {
      name = "libxslt.relocate";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${../jdk-support-relocate.py} "$out" "$TVP_ARTIFACT_ROOT"'';
    }
    (lib.optional final.repairPkgconfigRequires {
      name = "libxslt.pkgconfig-requires";
      tools = [
        tools.grep
        tools.sed
      ];
      run = ''
        pc="$out/lib/pkgconfig/libxslt.pc"
        test "$(grep -Fxc 'Requires:' "$pc")" -eq 1
        sed -i 's/^Requires:$/Requires: libxml-2.0/' "$pc"
      '';
    })
    (outputs.shebangs {
      paths = [ "bin/xslt-config" ];
      names = [ "sh" ];
      interpreter = "${final.runtime.shell}/bin/bash";
    })
    (outputs.strip { inherit paths; })
    (outputs.rpaths {
      inherit paths;
      libraries = final.runtime.libraries;
    })
    (outputs.development { libraries = [ final.libxml2 ] ++ lib.optional cryptoEnabled final.libgcrypt; })
    (outputs.checkPaths { inherit paths; })
  ];
  meta = {
    description = "XSLT processor and libraries based on libxml2";
    homepage = "https://gitlab.gnome.org/GNOME/libxslt";
    inherit (final) license;
    mainProgram = "xsltproc";
    platforms = [ "x86_64-linux" ];
  };
}
