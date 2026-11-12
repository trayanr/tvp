# One suite, shared by every libxml2 version. Never fork it per builder: a test
# that exists only for newer versions cannot detect drift in an older one.
# Guards select whole tests; they never edit a test body.
{
  pkgs,
  tvpLib,
  libxml2,
  pkg-config,
  gzip,
  xz,
}:
let
  specification = libxml2.specification or { };
  deps = libxml2.passthru.tvp.deps or { };
  features = libxml2.passthru.tvp.features or { };

  mkSuite =
    if libxml2 ? testContext then
      args:
      libxml2.testContext.mkSuite {
        package = libxml2;
        libraries = [ libxml2 ];
        tests = builtins.mapAttrs (_: spec: {
          inherit (spec) script expected;
          tools = (spec.extraInputs or [ ]) ++ [ libxml2.tvp.deps.gnugrep ];
        }) args.tests;
      }
    else
      tvpLib.tests.mkSuite;

  doc = ''
    cp ${./fixtures/doc.xml} doc.xml
    cp ${./fixtures/doc.dtd} doc.dtd
    chmod +w doc.xml doc.dtd
  '';
in
mkSuite {
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
        extraInputs = [ gzip ];
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
        extraInputs = [ libxml2.tvp.cc ] ++ pkgs.lib.attrValues deps;
      };

      pkg-config = {
        script = ''
          export PKG_CONFIG_LIBDIR=${libxml2}/lib/pkgconfig
          pkg-config --modversion libxml-2.0
        '';
        expected = libxml2.version;
        extraInputs = [ pkg-config ];
      };
    }

    // pkgs.lib.optionalAttrs (libxml2 ? artifact) {
      relocated-metadata = {
        script = ''
          test "$(xml2-config --prefix)" = ${libxml2}
          export PKG_CONFIG_LIBDIR=${libxml2}/lib/pkgconfig
          test "$(pkg-config --variable=prefix libxml-2.0)" = ${libxml2}
          test -f ${libxml2}/include/libxml2/libxml/parser.h
          printf relocated
        '';
        expected = "relocated";
        extraInputs = [ pkg-config ];
      };
    }

    // pkgs.lib.optionalAttrs ((libxml2 ? artifact) && (features.static or false)) {
      static-api = {
        script = ''
          ${doc}
          cc ${./fixtures/compile.c} $(xml2-config --cflags) ${libxml2}/lib/libxml2.a $(pkg-config --static --libs libxml-2.0 | sed 's/-lxml2//g') -o static-api
          ./static-api
        '';
        expected = "catalogue";
        extraInputs = [
          pkg-config
          libxml2.tvp.cc
        ] ++ pkgs.lib.attrValues deps;
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

    // pkgs.lib.optionalAttrs (features.lzma or (deps ? xz)) {
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
        extraInputs = [ xz ];
      };

      # lzma above passes against any liblzma the loader reaches, never only
      # the declared one.
      xz-linkage = {
        script = ''
          ldd ${libxml2}/lib/libxml2.so | awk '/liblzma\.so/ { print $3 }' | grep -q "^${(deps.liblzma or deps.xz).out}/" && printf linked
        '';
        expected = "linked";
        extraInputs =
          if libxml2 ? testContext then
            [
              libxml2.tvp.cc.libc
              libxml2.tvp.deps.gawk
            ]
          else
            [ libxml2.tvp.cc.libc.bin ];
      };
    };
}
//
  pkgs.lib.optionalAttrs
    (
      libxml2 ? artifact
      && specification ? captureHelper
      && specification ? classificationBinding
      && (specification.doCheck or false)
    )
    {
      upstream = import ./upstream.nix {
        inherit libxml2;
        lib = pkgs.lib;
      };
    }
//
  pkgs.lib.optionalAttrs
    (builtins.elem libxml2.version [
      "2.15.3"
      "2.15.4"
    ])
    {
      # These are the two reviewed corpus profiles, not an API availability boundary.
      relaxng-corpus = import ./relaxng-corpus.nix { inherit pkgs libxml2; };
    }
