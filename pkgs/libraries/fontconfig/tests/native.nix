# Installed tools, cache/config data and discovery on the package's current owned base.
{ package }:
let
  d = package.specification;
  discovery = d.base.environment {
    tools = [ d.pkg-config ];
    libraries = [ package ];
  };
in
package.testContext.mkSuite {
  inherit package;
  tools = [
    d.pkg-config
    d.findutils
    d.grep
  ];
  libraries = [ package ];
  tests.consumer = {
    script = ''cc ${./fixtures/consumer.c} -lfontconfig -o consumer; ./consumer ${./fixtures/font.bdf}'';
    expected = package.version;
  };
  tests.installed = {
    script = ''
      # Isolate explicit-config behavior as well as the clean default lookup
      # consumer. Do not inherit user/system font search or debug settings.
      for variable in "''${!FC_@}"; do unset "$variable"; done
      unset FONTCONFIG_FILE FONTCONFIG_PATH FONTCONFIG_SYSROOT
      # Runtime caches must use the fixture directory mtime, not the build epoch.
      unset SOURCE_DATE_EPOCH
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
      fc-cat "$cache" > cache-fonts
      grep -F TVP cache-fonts >/dev/null
      test -s ${package}/share/xml/fontconfig/fonts.dtd
      test -s ${package}/share/gettext/its/fontconfig.its
      test -s ${package}/share/gettext/its/fontconfig.loc
      fc-pattern --format '%{family}\n' TVP > pattern
      test "$(cat pattern)" = TVP
      fc-conflist > configurations
      test -s configurations
      fc-genconf -f TVP -g monospace -l en fonts/font.bdf > generated.conf
      grep -F TVP generated.conf >/dev/null
      grep -F monospace generated.conf >/dev/null
      # This deliberately minimal font lacks English coverage.
      if fc-validate -l en fonts/font.bdf > validation 2>&1; then exit 1; fi
      test -s validation
      cflags=$(pkg-config --cflags fontconfig)
      libs=$(pkg-config --libs fontconfig)
      cc $cflags ${./fixtures/consumer.c} $libs -o consumer
      ./consumer fonts/font.bdf
      unset FONTCONFIG_FILE FONTCONFIG_PATH
      cc $cflags ${./fixtures/default-config.c} $libs -o default-config
      ./default-config ${package} >/dev/null
    '';
    expected = package.version;
  };
}
