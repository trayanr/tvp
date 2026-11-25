{ package, context, ... }:
let
  inherit (package.specification.base) tools;
in
context.mkSuite {
  inherit package;
  tools = [
    tools.pkg-config
    tools.grep
    tools.sed
  ];
  libraries = [ package ];
  tests = {
    config = {
      script = ''
        test "$(gpg-error-config --prefix)" = "${package}"
        gpgrt-config --libdir="${package}/lib" gpg-error --modversion
      '';
      expected = package.version;
    };
    consumer = {
      script = ''
        cat > consumer.c <<'EOF'
        #include <gpg-error.h>
        #include <stdio.h>
        int main(void) {
          const char *version = gpg_error_check_version(GPG_ERROR_VERSION);
          if (!version || gpg_err_code(gpg_error(GPG_ERR_ENOMEM)) != GPG_ERR_ENOMEM)
            return 1;
          puts(version);
          return 0;
        }
        EOF
        cc $(pkg-config --cflags gpg-error) consumer.c $(pkg-config --libs gpg-error) -o consumer
        ./consumer
      '';
      expected = package.version;
    };
  };
}
