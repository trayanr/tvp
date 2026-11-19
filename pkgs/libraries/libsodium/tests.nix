{ package, context, ... }:
context.mkSuite {
  inherit package;
  libraries = [ package ];
  tests.consumer = {
    tools = [ package.specification.base.tools.pkg-config ];
    script = ''
      "$CC" ${./consumer.c} $(pkg-config --cflags --libs libsodium) -o consumer
      ./consumer
    '';
    expected = package.version;
  };
}
