{ package, context, ... }:
context.mkSuite {
  inherit package;
  tools = [ package.specification.base.tools.pkg-config ];
  libraries = [ package ] ++ package.specification.environment.libraries;
  tests = {
    regex = {
      script = ''
        cat > regex.c <<'C'
        #include <glib.h>

        int main(void) {
          GError *error = NULL;
          GRegex *regex = g_regex_new("^[0-9]+$", 0, 0, &error);
          if (regex == NULL || error != NULL)
            return 1;
          gboolean valid = g_regex_match(regex, "123", 0, NULL)
                           && !g_regex_match(regex, "abc", 0, NULL);
          g_regex_unref(regex);
          return !valid;
        }
        C
        "$CC" $(pkg-config --cflags glib-2.0) regex.c -o regex $(pkg-config --libs glib-2.0)
        env -i ./regex
        printf regex-ok
      '';
      expected = "regex-ok";
    };
    resources = {
      script = ''
        printf 'embedded resource\n' > message.txt
        cat > test.gresource.xml <<'XML'
        <gresources>
          <gresource prefix="/tvp"><file>message.txt</file></gresource>
        </gresources>
        XML
        env -i ${package}/bin/glib-compile-resources --sourcedir=. --target=message.gresource test.gresource.xml
        env -i ${package}/bin/gresource extract message.gresource /tvp/message.txt
      '';
      expected = "embedded resource";
    };
    version = {
      script = "pkg-config --modversion glib-2.0";
      expected = package.version;
    };
  };
}
