{
  context,
  lib,
  package,
}:
let
  inherit (package.specification.base.tools) pkg-config;
  libxml2 = package.tvp.deps.libxml2;
in
context.mkSuite {
  inherit package;
  tools = [ pkg-config ];
  libraries = [
    package
    libxml2
  ];
  tests = {
    transform = {
      script = ''
        ${package}/bin/xsltproc ${./transform.xsl} ${./input.xml}
      '';
      expected = "xslt=42";
    };
    config = {
      script = ''
        test "$(${package}/bin/xslt-config --version)" = ${lib.escapeShellArg package.version}
        printf 'configured'
      '';
      expected = "configured";
    };
  }
  // lib.optionalAttrs package.specification.installedInterface.pkgconfig {
    consumer = {
      script = ''
        test "$(pkg-config --modversion libxslt)" = ${lib.escapeShellArg package.version}
        "$CC" ${./consumer.c} $(pkg-config --cflags --libs libxslt) -o consumer
        ./consumer
      '';
      expected = "libxslt";
    };
  };
}
