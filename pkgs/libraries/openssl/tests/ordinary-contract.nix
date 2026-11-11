# Installed consumers cover the legacy and provider ABIs using public headers.
{ package }:
let
  deps = package.tvp.deps;
in
package.testContext.mkSuite {
  inherit package;
  tools = package.specification.environment.tools ++ [ deps.binutils ];
  libraries = [ package ];
  tests = {
    mutation-guards = {
      script = ''
        ${deps.python}/bin/python3 -B ${./ordinary-guards.py} '${builtins.toJSON {
          readelf = "${deps.binutils}/bin/readelf";
          patchelf = "${deps.patchelf}/bin/patchelf";
          perl = "${package.runtime.perl}/bin/perl";
          shell = "${package.runtime.shell}/bin/bash";
        }}' ${../ordinary/output.py} ${../ordinary/archive.py} ${../ordinary/elf.py} ${../../../runtimes/perl/ordinary/elf-finalize.py}
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
  } // (if package.tvp.features.providers then {
    provider-interface = {
      script = ''
        openssl list -providers -provider default -provider legacy > providers
        grep -F 'Legacy Provider' providers >/dev/null
        printf tvp | openssl dgst -provider legacy -md4 >/dev/null
        printf providers-ok
      '';
      expected = "providers-ok";
    };
  } else { });
}
