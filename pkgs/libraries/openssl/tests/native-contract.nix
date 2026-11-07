{ package }:
let
  deps = package.tvp.deps;
in
package.testContext.mkSuite {
  inherit package;
  tools = package.specification.environment.tools ++ [
    deps.python
    deps.binutils
    deps.patchelf
  ];
  libraries = [ package ];
  tests =
    {
      static-archives = {
        script = ''
          cc ${./fixtures/digest.c} ${package}/lib/libcrypto.a -ldl -pthread -o static-digest
          readelf -d static-digest > dynamic
          if grep -E 'NEEDED.*lib(crypto|ssl)' dynamic; then exit 1; fi
          test "$(./static-digest)" = f6f6ead0bd85c312
          cat > ssl.c <<'C'
          #include <openssl/ssl.h>
          int main(void) { SSL_CTX *c=SSL_CTX_new(TLS_method()); if(!c)return 1; SSL_CTX_free(c); }
          C
          cc ssl.c ${package}/lib/libssl.a ${package}/lib/libcrypto.a -ldl -pthread -o static-ssl
          ./static-ssl
          readelf -d static-ssl > dynamic
          if grep -E 'NEEDED.*lib(crypto|ssl)' dynamic; then exit 1; fi
          printf static-ok
        '';
        expected = "static-ok";
      };
      providers = {
        script = ''
          openssl list -providers -provider default -provider legacy > providers
          grep -F 'Legacy Provider' providers >/dev/null
          printf tvp | openssl dgst -provider legacy -md4 > digest
          if OPENSSL_MODULES="$PWD/missing" openssl list -providers -provider legacy >bad.out 2>bad.err; then exit 1; fi
          test -s bad.err
          test -d ${package}/lib/cmake/OpenSSL
          for module in openssl libssl libcrypto; do
            test "$(pkg-config --modversion "$module")" = ${package.version}
          done
          printf providers-ok
        '';
        expected = "providers-ok";
      };
      local-tls = {
        script = ''
          openssl req -config /dev/null -x509 -newkey rsa:2048 -noenc -keyout key.pem -out cert.pem -days 1 -subj /CN=localhost > cert.log 2>&1
          openssl verify -CAfile cert.pem cert.pem > verify.log
          if openssl verify -no-CAfile -no-CApath -no-CAstore cert.pem >bad.out 2>bad.err; then exit 1; fi
          cc ${./fixtures/native-tls.c} -lssl -lcrypto -o tls
          ./tls
          LD_TRACE_LOADED_OBJECTS=1 ./tls > loaded
          grep -F '${package}/lib/libssl.so.' loaded >/dev/null
          grep -F '${package}/lib/libcrypto.so.' loaded >/dev/null
          printf tls-ok
        '';
        expected = "tls-ok";
      };
    }
    // (
      if package.tvp.features.rehash then
        {
          c-rehash = {
            script = ''
              mkdir certs
              openssl req -config /dev/null -x509 -newkey rsa:2048 -noenc -keyout key.pem -out certs/ca.pem -days 1 -subj /CN=rehash > cert.log 2>&1
              PATH= ${package}/bin/c_rehash certs > rehash.log
              hash=$(openssl x509 -in certs/ca.pem -noout -subject_hash)
              test -L "certs/$hash.0"
              test "$(readlink "certs/$hash.0")" = ca.pem
              printf rehash-ok
            '';
            expected = "rehash-ok";
          };
        }
      else
        { }
    );
}
