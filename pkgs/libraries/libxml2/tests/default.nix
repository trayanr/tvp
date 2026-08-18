# One suite, shared by every libxml2 version. Never fork it per builder: a test
# that exists only for newer versions cannot detect drift in an older one.
# Guards select whole tests; they never edit a test body.
{
  pkgs,
  tvpLib,
  libxml2,
}:
let
  doc = ''
    cp ${./fixtures/doc.xml} doc.xml
    cp ${./fixtures/doc.dtd} doc.dtd
    chmod +w doc.xml doc.dtd
  '';
in
tvpLib.tests.mkSuite {
  inherit pkgs;
  package = libxml2;

  tests = {
    # xmllint --version writes to stderr; xml2-config is the stable reporter.
    version = {
      script = ''
        xml2-config --version
      '';
      expected = libxml2.version;
    };

    xpath = {
      script = ''
        ${doc}
        xmllint --xpath 'string(//package[@name="tvp"]/@version)' doc.xml
      '';
      expected = "1.2.3";
    };

    # DTD validation exercises a different engine from parsing, and it is what
    # downstream consumers most often rely on libxml2 for.
    validate = {
      script = ''
        ${doc}
        xmllint --noout --valid doc.xml && printf valid
      '';
      expected = "valid";
    };

    # libxml2 transparently reads gzipped XML only when it was built against
    # zlib, so this proves the declared dependency is actually wired in.
    gzip = {
      script = ''
        ${doc}
        gzip -c doc.xml > doc.xml.gz
        xmllint --xpath 'count(//package)' doc.xml.gz
      '';
      expected = "2";
      extraInputs = [ pkgs.gzip ];
    };

    pkg-config = {
      script = ''
        pkg-config --modversion libxml-2.0
      '';
      expected = libxml2.version;
      extraInputs = [ pkgs.pkg-config ];
    };
  };
}
