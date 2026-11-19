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
  make = ''
    build_date=$(date -u -d "@$(cat "$TVP_SOURCE_ROOT/source-date-epoch")" +%F)
    ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash \
      CC="$CC" CXX="$CXX" AR="$AR" CFLAGS="-g -Wall -std=gnu17" CXXFLAGS="-g -Wall" \
      RPATH="-Wl,-rpath,$out/lib" \
      BUILDFOR= TVP_BUILD_DATE="$build_date" PREFIX="$out" LIBDIR="$out/lib" USRLIBDIR="$out/lib" \
      ETCDIR="$out/etc" BINDIR="$out/bin" SBINDIR="$out/sbin" SHAREDIR="$out/share/keyutils" \
      MANDIR="$out/share/man" INCLUDEDIR="$out/include"'';
in
{
  pname = "keyutils";
  inherit base src version;
  inherit (tools) bash coreutils;
  environment.tools = [
    tools.gnumake
    tools.grep
    tools.sed
  ];
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (command "keyutils.prepare" ''
      grep -Fq '$(shell date -u +%F)' Makefile
      sed -i 's/$(shell date -u +%F)/$(TVP_BUILD_DATE)/' Makefile
    '')
    (command "keyutils.build" make)
    (command "keyutils.install" ''
      ${make} install
      test "$(readlink "$out/lib/libkeyutils.so")" = "$out/lib/libkeyutils.so.1"
      ln -sfn libkeyutils.so.1 "$out/lib/libkeyutils.so"
    '')
    (steps.split "keyutils.finalize")
    (outputs.copyArtifacts { })
    (outputs.relocateText { paths = [ "lib/pkgconfig/libkeyutils.pc" ]; })
    (outputs.shebangs {
      paths = [ "share/keyutils/request-key-debug.sh" ];
      names = [ "sh" ];
      interpreter = "${tools.bash}/bin/bash";
    })
    {
      name = "output.request-key-helpers";
      tools = [ tools.sed ];
      run = ''
        # request-key reads the host's /etc. Keep the shipped sample usable
        # when an administrator installs it there.
        sed -i \
          -e "s|/sbin/key.dns_resolver|$out/sbin/key.dns_resolver|g" \
          -e "s|/bin/keyctl|$out/bin/keyctl|g" \
          -e "s|/bin/cat|${tools.coreutils}/bin/cat|g" \
          -e "s|/usr/share/keyutils/request-key-debug.sh|$out/share/keyutils/request-key-debug.sh|g" \
          "$out/etc/request-key.conf"
        sed -i \
          -e "s|^\([[:space:]]*\)keyctl |\1$out/bin/keyctl |" \
          -e "s|^\([[:space:]]*\)cat /proc/keys$|\1${tools.coreutils}/bin/cat /proc/keys|" \
          "$out/share/keyutils/request-key-debug.sh"
      '';
    }
    (outputs.strip {
      paths = [
        "bin"
        "sbin"
        "lib"
      ];
    })
    (outputs.stripArchives { paths = [ "lib/libkeyutils.a" ]; })
    (outputs.rpaths {
      paths = [
        "bin"
        "sbin"
        "lib"
      ];
      libraries = final.runtime.libraries;
    })
    (outputs.checkPaths {
      paths = [
        "bin"
        "sbin"
        "lib"
      ];
    })
  ];
  meta = {
    description = "Linux kernel key management tools and library";
    homepage = "https://git.kernel.org/pub/scm/linux/kernel/git/dhowells/keyutils.git/";
    license = [
      lib.licenses.gpl2Plus
      lib.licenses.lgpl21Plus
    ];
    platforms = [ "x86_64-linux" ];
  };
}
