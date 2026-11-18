{ package, context, ... }:
context.mkSuite {
  inherit package;
  libraries = [ package ];
  tests.consumer = {
    tools = [ package.specification.base.tools.pkg-config ];
    script = ''
      "$CC" ${./consumer.c} $(pkg-config --cflags --libs libjpeg) -o consumer
      ./consumer
    '';
    expected = "jpeg";
  };
}
