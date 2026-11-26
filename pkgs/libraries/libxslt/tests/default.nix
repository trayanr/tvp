{
  context,
  lib,
  package,
}:
let
  inherit (package.specification.base.tools) pkg-config;
  libxml2 = package.tvp.deps.libxml2;
  bindingPython = libxml2.specification.bindingPython or null;
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
  }
  // lib.optionalAttrs (package.tvp.features.crypto or false) {
    crypto = {
      script = ''
        cat > crypto.xsl <<'XSL'
        <xsl:stylesheet version="1.0"
          xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
          xmlns:crypto="http://exslt.org/crypto">
          <xsl:output method="text"/>
          <xsl:template match="/">
            <xsl:value-of select="crypto:sha1('abc')"/>
          </xsl:template>
        </xsl:stylesheet>
        XSL
        ${package}/bin/xsltproc crypto.xsl ${./input.xml}
      '';
      expected = "a9993e364706816aba3e25717850c26c9cd0d89d";
    };
  }
  // lib.optionalAttrs (package.tvp.features.python or false) {
    python = {
      script = ''
        export PYTHONPATH=${package.development.pythonModuleDirectory}:${libxml2.development.pythonModuleDirectory}
        ${bindingPython}/bin/python3 -B - ${./transform.xsl} ${./input.xml} <<'PYTHON'
        import sys
        import libxml2
        import libxslt

        style = libxslt.parseStylesheetDoc(libxml2.parseFile(sys.argv[1]))
        doc = libxml2.parseFile(sys.argv[2])
        result = style.applyStylesheet(doc, None)
        text = style.saveResultToString(result)
        assert text in ("xslt=42", b"xslt=42")
        result.freeDoc()
        doc.freeDoc()
        style.freeStylesheet()
        print("python-libxslt")
        PYTHON
      '';
      expected = "python-libxslt";
    };
  };
}
