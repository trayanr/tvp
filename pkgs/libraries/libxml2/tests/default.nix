# One suite, shared by every libxml2 version. Never fork it per builder: a test
# that exists only for newer versions cannot detect drift in an older one.
# Guards select whole tests; they never edit a test body.
{
  pkgs,
  tvpLib,
  libxml2,
}:
let
  deps = libxml2.passthru.tvp.deps or { };
  features = libxml2.passthru.tvp.features or { };

  doc = ''
    cp ${./fixtures/doc.xml} doc.xml
    cp ${./fixtures/doc.dtd} doc.dtd
    chmod +w doc.xml doc.dtd
  '';
in
tvpLib.tests.mkSuite {
  inherit pkgs;
  package = libxml2;

  tests =
    {
      # xmllint --version writes to stderr; xml2-config is the stable reporter.
      version = {
        script = ''
          xml2-config --version
        '';
        expected = libxml2.version;
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
      # --valid rather than --xpath: a partial decompression would still parse,
      # and --xpath does not exist before 2.7.7.
      gzip = {
        script = ''
          ${doc}
          gzip -c doc.xml > doc.xml.gz
          xmllint --noout --valid doc.xml.gz && printf gzip-ok
        '';
        expected = "gzip-ok";
        extraInputs = [ pkgs.gzip ];
      };

      # Consumers compile against the installed headers, and a library that
      # builds can still install headers that do not.
      compile = {
        script = ''
          ${doc}
          cc ${./fixtures/compile.c} $(xml2-config --cflags --libs) -o compile
          ./compile
        '';
        expected = "catalogue";
        # The declared graph, because xml2-config emits -lz and -llzma.
        extraInputs = [ pkgs.stdenv.cc ] ++ pkgs.lib.attrValues deps;
      };

      pkg-config = {
        script = ''
          pkg-config --modversion libxml-2.0
        '';
        expected = libxml2.version;
        extraInputs = [ pkgs.pkg-config ];
      };
    }

    # xmllint gained --xpath at 2.7.7; below that the engine is reachable only
    # through --shell, which is a different code path from what consumers use.
    // pkgs.lib.optionalAttrs (features.xpath or true) {
      xpath = {
        script = ''
          ${doc}
          xmllint --xpath 'string(//package[@name="tvp"]/@version)' doc.xml
        '';
        expected = "1.2.3";
      };
    }

    // pkgs.lib.optionalAttrs (deps ? xz) {
      # libxml2 reads xz-compressed XML only when it was built --with-lzma.
      # 2.15 removed that support, so the guard drops the test with the
      # dependency rather than needing a version comparison.
      lzma = {
        script = ''
          ${doc}
          xz -c doc.xml > doc.xml.xz
          xmllint --noout --valid doc.xml.xz && printf lzma-ok
        '';
        expected = "lzma-ok";
        extraInputs = [ pkgs.xz ];
      };

      # The capability works against any liblzma the loader can reach, so only
      # this proves the declared one is what libxml2 was linked against.
      xz-linkage = {
        script = ''
          ldd ${libxml2}/lib/libxml2.so | awk '/liblzma\.so/ { print $3 }' | grep -q "^${deps.xz.out}/" && printf linked
        '';
        expected = "linked";
        extraInputs = [ pkgs.glibc.bin ];
      };
    };
}
