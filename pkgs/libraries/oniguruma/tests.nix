{ package, context, ... }:
context.mkSuite {
  inherit package;
  libraries = [ package ];
  tools = [ package.specification.base.tools.pkg-config ];
  tests = {
    metadata = {
      script = ''
        test "$(pkg-config --variable=prefix oniguruma)" = "${package}"
        test "$(pkg-config --modversion oniguruma)" = "$(onig-config --version)"
        test "$(PATH= ${package}/bin/onig-config --prefix=/fixture --prefix)" = /fixture
        onig-config --version
      '';
      expected = package.version;
    };
    utf8 = {
      script = ''
        "$CC" ${./utf8.c} $(pkg-config --cflags --libs oniguruma) -o consumer
        ./consumer
      '';
      expected = "utf8-match";
    };
  };
}
