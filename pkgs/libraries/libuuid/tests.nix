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

        static int roundtrip(const uuid_t generated, int type) {
          uuid_t parsed;
          char text[37];
          uuid_unparse_lower(generated, text);
          if (uuid_parse(text, parsed) != 0 || uuid_compare(generated, parsed) != 0)
            return 0;
          return uuid_type(parsed) == type && !uuid_is_null(parsed);
        }

        int main(void) {
          uuid_t generated;
          uuid_generate_random(generated);
          if (!roundtrip(generated, UUID_TYPE_DCE_RANDOM))
            return 1;
          uuid_generate_time(generated);
          if (!roundtrip(generated, UUID_TYPE_DCE_TIME))
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
