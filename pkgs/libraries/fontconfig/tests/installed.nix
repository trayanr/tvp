# Installed consumers shared by canonical, opt-in and customized packages.
{
  pkgs,
  tvpLib,
  package,
}:
let
  discovery = package.specification.base.environment {
    tools = [ package.tvp.deps.pkg-config ];
    libraries = [ package ];
  };
in
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests.installed = {
    script = ''
      # Isolate explicit-config behavior as well as the clean default lookup
      # consumer. Do not inherit user/system font search or debug settings.
      for variable in "''${!FC_@}"; do unset "$variable"; done
      unset FONTCONFIG_FILE FONTCONFIG_PATH FONTCONFIG_SYSROOT
      export XDG_CONFIG_HOME="$TMPDIR/config" XDG_DATA_HOME="$TMPDIR/data"
      export HOME="$TMPDIR/home" XDG_CACHE_HOME="$TMPDIR/cache"
      mkdir -p "$HOME" "$XDG_CACHE_HOME" fonts
      cp ${./fixtures/font.bdf} fonts/font.bdf
      cat > fonts.conf <<EOF_CONFIG
      <?xml version="1.0"?>
      <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
      <fontconfig><dir>$PWD/fonts</dir><cachedir>$XDG_CACHE_HOME/fontconfig</cachedir></fontconfig>
      EOF_CONFIG
      export FONTCONFIG_FILE="$PWD/fonts.conf" FONTCONFIG_PATH="$PWD"
      family=$(fc-query --format '%{family}' fonts/font.bdf)
      test "$family" = TVP
      family=$(fc-scan --format '%{family}' fonts/font.bdf)
      test "$family" = TVP
      fc-cache -f fonts
      family=$(fc-list --format '%{family}')
      test "$family" = TVP
      family=$(fc-match --format '%{family}' TVP)
      test "$family" = TVP
      cache=$(find "$XDG_CACHE_HOME/fontconfig" -name '*cache-*' -print -quit)
      test -n "$cache"
      export PKG_CONFIG_PATH='${discovery.env.PKG_CONFIG_PATH}'
      export PKG_CONFIG_LIBDIR='${discovery.env.PKG_CONFIG_LIBDIR}'
      export PKG_CONFIG_SYSROOT_DIR='${discovery.env.PKG_CONFIG_SYSROOT_DIR}'
      version=$(pkg-config --modversion fontconfig)
      test "$version" = ${package.version}
      cflags=$(pkg-config --cflags fontconfig)
      libs=$(pkg-config --libs fontconfig)
      cc $cflags ${./fixtures/consumer.c} $libs -o consumer
      ./consumer fonts/font.bdf
    '';
    expected = package.version;
    extraInputs = [
      package.tvp.cc
      package.tvp.deps.pkg-config
    ];
  };
}
