{
  package,
  context,
  ...
}:
context.mkSuite {
  inherit package;
  libraries = [ package ];
  tests = {
    pkg-config = {
      tools = [ package.specification.base.tools.pkg-config ];
      script = "pkg-config --modversion libzip";
      expected = package.version;
    };
    archive = {
      script = ''
        ${package}/bin/ziptool -n fixture.zip add example.txt sample-content
        ${package}/bin/ziptool -c fixture.zip cat 0
      '';
      expected = "sample-content";
    };
  };
}
