{ package, context, ... }:
context.mkSuite {
  inherit package;
  tests.version = {
    script = ''${package}/bin/odbcinst --version'';
    expected = "unixODBC ${package.version}";
  };
}
