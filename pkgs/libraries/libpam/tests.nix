{ package, context, ... }:
let
  inherit (package.specification.base) tools;
in
context.mkSuite {
  inherit package;
  tools = [ tools.pkg-config ];
  libraries = [ package ];
  tests = {
    local-config = {
      script = ''
        mkdir services
        printf '%s\n' 'auth required pam_permit.so' > services/tvp-allow
        printf '%s\n' 'auth required pam_deny.so' > services/tvp-deny
        cat > consumer.c <<'EOF'
        #include <security/pam_appl.h>
        #include <stdio.h>

        static int converse(int count, const struct pam_message **messages,
                            struct pam_response **responses, void *data) {
          (void) count;
          (void) messages;
          (void) responses;
          (void) data;
          return PAM_CONV_ERR;
        }

        static int check(const char *name, int expected) {
          struct pam_conv conversation = { converse, NULL };
          pam_handle_t *handle = NULL;
          int status = pam_start_confdir(name, "tvp-fixture", &conversation,
                                        "services", &handle);
          if (status != PAM_SUCCESS)
            return 1;
          status = pam_authenticate(handle, 0);
          return pam_end(handle, status) != PAM_SUCCESS || status != expected;
        }

        int main(void) {
          if (check("tvp-allow", PAM_SUCCESS) || check("tvp-deny", PAM_AUTH_ERR))
            return 1;
          puts("PAM local configuration");
          return 0;
        }
        EOF
        cc $(pkg-config --cflags pam) consumer.c $(pkg-config --libs pam) -o consumer
        ./consumer
      '';
      expected = "PAM local configuration";
    };
    metadata = {
      script = "pkg-config --modversion pam";
      expected = package.version;
    };
  };
}
