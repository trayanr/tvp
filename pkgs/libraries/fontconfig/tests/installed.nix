# Separate from the canonical suite so existing test derivations stay exact.
{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests.installed = {
    script = ''
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
      export PKG_CONFIG_PATH="${package}/lib/pkgconfig:${package.tvp.deps.freetype}/lib/pkgconfig:${package.tvp.deps.expat}/lib/pkgconfig"
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
