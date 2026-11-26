{ package, context, ... }:
let
  inherit (package.specification.base) tools;
in
context.mkSuite {
  inherit package;
  tools = [ tools.grep ];
  tests = {
    version = {
      script = "doxygen --version";
      expected = package.version;
    };
    xml = {
      script = ''
        cat > sample.h <<'EOF'
        /** A documented answer function. */
        int documented_answer(void);
        EOF
        cat > Doxyfile <<'EOF'
        PROJECT_NAME = example
        INPUT = sample.h
        EXTRACT_ALL = YES
        GENERATE_HTML = NO
        GENERATE_LATEX = NO
        GENERATE_XML = YES
        QUIET = YES
        EOF
        doxygen Doxyfile
        test -s xml/index.xml
        grep -Fq '<name>documented_answer</name>' xml/sample_8h.xml
        printf '%s\n' 'XML'
      '';
      expected = "XML";
    };
  };
}
