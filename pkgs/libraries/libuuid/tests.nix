{ package, context, ... }:
let
  inherit (package.specification.base) tools;
in
context.mkSuite {
  inherit package;
  tools = [ tools.pkg-config ];
  libraries = [ package ];
  tests = {
    consumer = {
      script = ''
        cat > consumer.c <<'EOF'
        #include <stdio.h>
        #include <uuid/uuid.h>

        int main(void) {
          uuid_t generated, parsed;
          char text[37];
          uuid_generate_random(generated);
          uuid_unparse_lower(generated, text);
          if (uuid_parse(text, parsed) != 0 || uuid_compare(generated, parsed) != 0)
            return 1;
          if (uuid_type(parsed) != UUID_TYPE_DCE_RANDOM || uuid_is_null(parsed))
            return 1;
          puts("UUID round trip");
          return 0;
        }
        EOF
        cc $(pkg-config --cflags uuid) consumer.c $(pkg-config --libs uuid) -o consumer
        ./consumer
      '';
      expected = "UUID round trip";
    };
    metadata = {
      script = "pkg-config --modversion uuid";
      expected = package.version;
    };
  };
}
