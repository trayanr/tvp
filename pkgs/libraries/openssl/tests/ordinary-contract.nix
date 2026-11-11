# Installed consumers cover the legacy and provider ABIs using public headers.
{ package }:
let
  deps = package.tvp.deps;
  features = package.tvp.features;
  engineDirectory =
    if features.providers then
      "engines-3"
    else if features.tlsMethod then
      "engines-1.1"
    else
      "engines";
in
package.testContext.mkSuite {
  inherit package;
  tools =
    package.specification.environment.tools
    ++ [ deps.binutils ]
    ++ (if features.cmake then [ deps.testCmake ] else [ ]);
  libraries = [ package ];
  tests =
    {
      mutation-guards = {
        script = ''
          ${deps.python}/bin/python3 -B ${./ordinary-guards.py} '${
            builtins.toJSON {
              readelf = "${deps.binutils}/bin/readelf";
              patchelf = "${deps.patchelf}/bin/patchelf";
              perl = "${package.runtime.perl}/bin/perl";
              shell = "${package.runtime.shell}/bin/bash";
            }
          }' ${../ordinary/output.py} ${../ordinary/archive.py} ${../ordinary/elf.py} ${../../../../lib/installed-tree.py} ${../ordinary/source.py}
          printf guards-ok
        '';
        expected = "guards-ok";
      };
      installed-abi = {
        script = ''
          cc ${./fixtures/ordinary-abi.c} -lssl -lcrypto -o shared-abi
          ./shared-abi
          LD_TRACE_LOADED_OBJECTS=1 ./shared-abi > loaded
          grep -F '${package}/lib/libssl.so' loaded >/dev/null
          grep -F '${package}/lib/libcrypto.so' loaded >/dev/null
          cc ${./fixtures/ordinary-abi.c} ${package}/lib/libssl.a ${package}/lib/libcrypto.a -ldl -pthread -o static-abi
          ./static-abi
          readelf -d static-abi > dynamic
          if grep -E 'NEEDED.*lib(ssl|crypto)' dynamic; then exit 1; fi
          for module in openssl; do
            test "$(pkg-config --modversion "$module")" = ${package.version}
          done
          printf abi-ok
        '';
        expected = "abi-ok";
      };
      artifact-excluded = {
        script = ''
          test ! -e ${package}/nix-support/upstream.raw
          test ! -e ${package}/nix-support/upstream.exit
          test -f ${package}/include/openssl/ssl.h
          printf installed-ok
        '';
        expected = "installed-ok";
      };
      installed-paths = {
        script = ''
          openssl version -d > directory
          grep -F '${package}/etc/ssl' directory >/dev/null
          for module in openssl libssl libcrypto; do
            test "$(pkg-config --variable=prefix "$module")" = ${package}
            test "$(pkg-config --modversion "$module")" = ${package.version}
          done
          printf paths-ok
        '';
        expected = "paths-ok";
      };
    }
    // (
      if package.tvp.features.providers then
        {
          provider-interface = {
            script = ''
              LD_DEBUG=files openssl list -providers -provider default -provider legacy > providers 2>loaded
              grep -F '${package}/lib/ossl-modules/legacy.so' loaded >/dev/null
              openssl version -m | grep -F '${package}/lib/ossl-modules' >/dev/null
              grep -F 'Legacy Provider' providers >/dev/null
              printf tvp | openssl dgst -provider legacy -md4 >/dev/null
              printf providers-ok
            '';
            expected = "providers-ok";
          };
        }
      else
        { }
    )
    // (
      if features.rehash then
        {
          c-rehash = {
            script = ''
              mkdir certs
              openssl req -config /dev/null -new -x509 -newkey rsa:2048 -nodes -sha1 \
                -keyout key.pem -out certs/ca.pem -days 1 -subj /CN=rehash >cert.log 2>&1
              test "$(head -n1 ${package}/bin/c_rehash)" = '#!${package.runtime.perl}/bin/perl'
              unset OPENSSL
              PATH= ${package}/bin/c_rehash certs >rehash.log
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
    )
    // (
      if features.engines then
        {
          engine-module = {
            script = ''
              find ${package}/lib/${engineDirectory} -maxdepth 1 -type f -name '*.so' >modules
              test -s modules
              IFS= read -r engine <modules
              cc ${./fixtures/engine-load.c} -Wl,--no-as-needed -lcrypto -ldl -o engine-load
              LD_DEBUG=files ./engine-load "$engine" >result 2>loaded
              grep -F "$engine" loaded >/dev/null
              grep -F '${package}/lib/libcrypto.so' loaded >/dev/null
              printf engine-ok
            '';
            expected = "engine-ok";
          };
        }
      else
        { }
    )
    // (
      if features.engines && features.tlsMethod then
        {
          engine-directory = {
            script = ''
              openssl version -e | grep -F '${package}/lib/${engineDirectory}' >/dev/null
              printf engine-path-ok
            '';
            expected = "engine-path-ok";
          };
        }
      else
        { }
    )
    // (
      if features.cmake then
        {
          cmake-metadata = {
            script = ''
                    test -s ${package}/lib/cmake/OpenSSL/OpenSSLConfig.cmake
                    test -s ${package}/lib/cmake/OpenSSL/OpenSSLConfigVersion.cmake
                    ${deps.python}/bin/python3 -B - <<'PY'
                    from pathlib import Path
                    for path in Path('${package}/lib/cmake/OpenSSL').glob('*.cmake'):
                        body = path.read_bytes()
                        assert b'\0' not in body and b'${package.artifact}' not in body
                        body.decode('utf-8')
                    PY
              cmake -S ${./fixtures/cmake} -B cmake-build \
                -DOpenSSL_DIR=${package}/lib/cmake/OpenSSL \
                -DCMAKE_C_COMPILER="$CC" -DTEST_SOURCE=${./fixtures/ordinary-abi.c} >cmake.log
              cmake --build cmake-build >>cmake.log
              ./cmake-build/consumer
              LD_TRACE_LOADED_OBJECTS=1 ./cmake-build/consumer >loaded
              grep -F '${package}/lib/libssl.so' loaded >/dev/null
              grep -F '${package}/lib/libcrypto.so' loaded >/dev/null
                    printf cmake-ok
            '';
            expected = "cmake-ok";
          };
        }
      else
        { }
    );
}
