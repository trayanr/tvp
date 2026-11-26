{ package, context, ... }:
let
  inherit (package.specification.base) tools;
in
context.mkSuite {
  inherit package;
  tools = [
    tools.pkg-config
    tools.sed
  ];
  libraries = [
    package
    package.tvp.deps.libgpg-error
  ];
  tests = {
    config = {
      script = ''
        test "$(libgcrypt-config --prefix)" = "${package}"
        test "$(libgcrypt-config --version)" = "${package.version}"
        pkg-config --modversion libgcrypt
      '';
      expected = package.version;
    };
    consumer = {
      script = ''
        cat > consumer.c <<'EOF'
        #include <gcrypt.h>
        #include <stdio.h>
        int main(void) {
          const char *version = gcry_check_version(GCRYPT_VERSION);
          if (!version || gcry_md_get_algo_dlen(GCRY_MD_SHA256) != 32)
            return 1;
          puts(version);
          return 0;
        }
        EOF
        cc $(pkg-config --cflags libgcrypt) consumer.c $(pkg-config --libs libgcrypt) -o consumer
        ./consumer
      '';
      expected = package.version;
    };
  };
}
