{
  package,
  context,
  ...
}:
context.mkSuite {
  inherit package;
  libraries = [ package ];
  tests = {
    normalize = {
      script = ''printf 'e\314\201' | ${package}/bin/uconv -f UTF-8 -t UTF-8 -x Any-NFC'';
      expected = "é";
    };
    collate = {
      tools = [ package.tvp.declaredTestDependencies.pkg-config ];
      script = ''
        export PKG_CONFIG_LIBDIR=${package}/lib/pkgconfig
        test "$(pkg-config --modversion icu-i18n)" = ${package.version}
        "$CC" ${./collation.c} $(pkg-config --cflags --libs icu-i18n) -Wl,-rpath,${package}/lib -o collate
        ./collate
      '';
      expected = "sv-SE";
    };
    icu-config = {
      script = ''
        test "$(${package}/bin/icu-config --prefix)" = ${package}
        ${package}/bin/icu-config --version
      '';
      expected = package.version;
    };
  };
}
