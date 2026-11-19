{
  tvp,
  lib,
  base,
  src,
  version,
  bison,
  keyutils,
  openssl,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = steps.command {
    cwd = "source/src";
    environment = final.environment;
  };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'';
  installedScripts = [
    "bin/compile_et"
    "bin/k5srvutil"
    "bin/krb5-config"
  ];
  elfPaths = [
    "bin"
    "lib"
    "sbin"
  ];
in
{
  pname = "krb5";
  inherit
    base
    src
    version
    bison
    keyutils
    openssl
    ;
  inherit (tools) bash coreutils;
  environment = {
    tools = [
      final.bison
      tools.gawk
      tools.gnumake
      tools.grep
      tools.perl
      tools.pkg-config
      tools.sed
    ];
    libraries = [
      final.keyutils
      final.openssl
    ];
    # This release predates GCC's default C23 language mode.
    overrides.values.CFLAGS = "-O2 -std=gnu17";
  };
  runtime.libraries = [
    final.keyutils
    final.openssl
  ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (steps.shebangs {
      name = "krb5.prepare-scripts";
      cwd = "source/src";
      paths = [
        "configure"
        "config/config.guess"
        "config/config.sub"
        "config/install-sh"
        "config/mkinstalldirs"
        "config/move-if-changed"
        "kadmin/scripts/inst-hdrs.sh"
        "util/et/config_script"
        "util/getsyms"
        "util/ss/config_script"
      ];
      names = [ "sh" ];
      interpreter = "${tools.bash}/bin/bash";
    })
    (command "krb5.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash
      export YACC='${final.bison}/bin/bison -y'
      export AWK=${tools.gawk}/bin/awk SED=${tools.sed}/bin/sed
      ./configure --prefix="$out" --sysconfdir=/etc --localstatedir=/var/lib --runstatedir=/run \
        --enable-shared --disable-static --with-keyutils --with-tls-impl=openssl \
        --without-ldap --without-libedit --without-system-verto
    '')
    (command "krb5.build" make)
    (command "krb5.install" ''
      ${make} DESTDIR="$PWD/installed" install
      mkdir -p "$out"
      cp -a "$PWD/installed$out/." "$out/"
    '')
    (steps.split "krb5.finalize")
    (outputs.copyArtifacts { })
    {
      name = "output.krb5-prefixes";
      tools = [
        tools.patchelf
        tools.python
      ];
      # Kerberos also embeds its default plugin directories in native libraries.
      run = ''${tools.python}/bin/python3 -B ${../../../lib/relocate.py} "$out" "$TVP_ARTIFACT_ROOT" ${tools.patchelf}/bin/patchelf'';
    }
    (outputs.shebangs {
      paths = installedScripts;
      names = [ "sh" ];
      interpreter = "${tools.bash}/bin/bash";
    })
    {
      name = "output.krb5-script-path";
      tools = [ tools.sed ];
      run = ''
        for script in ${lib.escapeShellArgs installedScripts}; do
          sed -i "1a export PATH=$out/bin:$out/sbin:${tools.coreutils}/bin:${tools.gawk}/bin:${tools.sed}/bin" "$out/$script"
        done
      '';
    }
    (outputs.strip { paths = elfPaths; })
    (outputs.rpaths {
      paths = elfPaths;
      libraries = final.runtime.libraries;
    })
    (outputs.checkPaths { paths = elfPaths; })
  ];
  meta = {
    description = "MIT Kerberos network authentication tools and libraries";
    homepage = "https://web.mit.edu/kerberos/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
