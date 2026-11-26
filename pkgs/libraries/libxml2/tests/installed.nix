# One installed suite for every public procedure, including latest.
{
  package,
  lib,
  context,
}:
let
  specification = package.specification;
  deps = package.tvp.deps;
  features = package.tvp.features;
  bindingPython = specification.bindingPython or null;
  tools = specification.base.tools;
  pkg-config = tools.pkg-config;
  gzip = tools.gzip;
  xz = tools.xz;
  runtimeLzma =
    let
      providers = builtins.filter (
        p:
        builtins.elem (p.pname or "") [
          "xz"
          "liblzma"
        ]
      ) specification.runtime.libraries;
    in
    if builtins.length providers == 1 then
      builtins.head providers
    else
      throw "Libxml2 test: exactly one effective LZMA runtime provider required";
  mkSuite =
    args:
    context.mkSuite {
      inherit package;
      libraries = [ package ];
      tests = builtins.mapAttrs (_: spec: {
        inherit (spec) script expected;
        tools = (spec.extraInputs or [ ]) ++ [
          tools.grep
          tools.sed
          tools.gawk
        ];
      }) args.tests;
    };
  doc = ''
    cp ${./fixtures/doc.xml} doc.xml
    cp ${./fixtures/doc.dtd} doc.dtd
    chmod +w doc.xml doc.dtd
  '';
in
mkSuite {
  inherit package;

  tests = {
    # xmllint --version writes to stderr; xml2-config is the stable reporter.
    version = {
      script = ''
        xml2-config --version
      '';
      expected = package.version;
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
      extraInputs = [ package.tvp.cc ] ++ lib.attrValues deps;
    };

    pkg-config = {
      script = ''
        export PKG_CONFIG_LIBDIR=${package}/lib/pkgconfig
        pkg-config --modversion libxml-2.0
      '';
      expected = package.version;
      extraInputs = [ pkg-config ];
    };
  }

  // lib.optionalAttrs (features.python or false) {
    python = {
      script = ''
        export PYTHONPATH=${package.development.pythonModuleDirectory}
        ${bindingPython}/bin/python3 -B - <<'PYTHON'
        import libxml2

        doc = libxml2.parseDoc("<package version='1.2.3'/>")
        assert doc.getRootElement().prop("version") == "1.2.3"
        doc.freeDoc()
        print("python-libxml2")
        PYTHON
      '';
      expected = "python-libxml2";
      extraInputs = [ bindingPython ];
    };
  }

  // lib.optionalAttrs (features.icu or false) {
    icu = {
      script = ''
        LD_TRACE_LOADED_OBJECTS=1 ${package}/bin/xmllint > libraries
        test "$(awk '/^[[:space:]]*libicuuc\.so\./ { print $3 }' libraries)" = \
          "${lib.getLib specification.icu}/lib/libicuuc.so.${lib.versions.major specification.icu.version}"
        printf icu
      '';
      expected = "icu";
    };
  }

  // lib.optionalAttrs (package ? artifact) {
    relocated-metadata = {
      script = ''
        test "$(xml2-config --prefix)" = ${package}
        export PKG_CONFIG_LIBDIR=${package}/lib/pkgconfig
        test "$(pkg-config --variable=prefix libxml-2.0)" = ${package}
        test -f ${package}/include/libxml2/libxml/parser.h
        printf relocated
      '';
      expected = "relocated";
      extraInputs = [ pkg-config ];
    };
  }

  // lib.optionalAttrs ((package ? artifact) && (features.static or false)) {
    static-api = {
      script = ''
        ${doc}
        cc ${./fixtures/compile.c} $(xml2-config --cflags) ${package}/lib/libxml2.a $(pkg-config --static --libs libxml-2.0 | sed 's/-lxml2//g') -o static-api
        ./static-api
      '';
      expected = "catalogue";
      extraInputs = [
        pkg-config
        package.tvp.cc
      ]
      ++ lib.attrValues deps;
    };
  }

  # xmllint gained --xpath at 2.7.7; below that the engine is reachable only
  # through --shell, which is a different code path from what consumers use.
  // lib.optionalAttrs (features.xpath or true) {
    xpath = {
      script = ''
        ${doc}
        xmllint --xpath 'string(//package[@name="tvp"]/@version)' doc.xml
      '';
      expected = "1.2.3";
    };
  }

  // lib.optionalAttrs (features.lzma or (deps ? xz)) {
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
        LD_TRACE_LOADED_OBJECTS=1 ${package}/bin/xmllint | awk '/liblzma\.so/ { print $3 }' | grep -q "^${lib.getLib runtimeLzma}/" && printf linked
      '';
      expected = "linked";
      extraInputs = [
        tools.gawk
      ];
    };
  };
}

//
  lib.optionalAttrs
    (builtins.elem package.version [
      "2.15.3"
      "2.15.4"
    ])
    {
      # Existing reviewed corpus profile; compatibility is not strict conformance.
      relaxng-corpus = import ./installed-corpus.nix { inherit package lib context; };
    }
// lib.optionalAttrs (specification.upstreamCheck.enabled or true) {
  upstream = import ./checkpoint-upstream.nix { inherit package lib context; };
}
