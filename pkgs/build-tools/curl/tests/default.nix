{
  pkgs,
  tvpLib,
  package,
}:
let
  mkSuite =
    if package ? testContext then
      args:
      package.testContext.mkSuite {
        inherit package;
        libraries = [ package ];
        tests = builtins.mapAttrs (_: spec: {
          inherit (spec) script expected;
          tools = (spec.extraInputs or [ ]) ++ [
            package.tvp.deps.gawk
            package.tvp.deps.gnugrep
          ];
        }) args.tests;
      }
    else
      tvpLib.tests.mkSuite;
in
mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = "curl --version | awk 'NR==1 {print $2}' ";
      expected = package.version;
    };
    library = {
      script = "cc -I${package}/include ${./fixtures/consumer.c} -L${package}/lib -lcurl -o consumer; ./consumer";
      expected = package.version;
      extraInputs = [ package.tvp.cc ];
    };
    trust = {
      script = "curl-config --ca";
      expected = "${package.tvp.deps.ca-certificates}/etc/ssl/certs/ca-bundle.crt";
    };
    http = {
      script = ''
        printf 42 | zstd -q -o body.zst
        python3 ${./fixtures/server.py} --port-file port --zstd body.zst > server.log 2>&1 &
        server=$!
        trap 'kill "$server" 2>/dev/null || true; wait "$server" 2>/dev/null || true' EXIT
        for attempt in $(seq 1 100); do if test -s port; then break; fi; sleep 0.05; done
        port=$(cat port)
        curl --connect-timeout 5 --max-time 15 --silent --fail --compressed "http://127.0.0.1:$port/gzip" > gzip.txt
        test "$(cat gzip.txt)" = 42
        curl --connect-timeout 5 --max-time 15 --silent --fail --compressed "http://127.0.0.1:$port/zstd"
      '';
      expected = "42";
      extraInputs = [
        package.tvp.deps.python
        package.tvp.deps.zstd
      ];
    };
    tls = {
      script = ''
        unset SSL_CERT_FILE SSL_CERT_DIR CURL_CA_BUNDLE
        openssl req -config ${./fixtures/certificate.cnf} -x509 -newkey rsa:2048 -nodes -days 1 \
          -keyout key.pem -out cert.pem > key.log 2>&1
        python3 ${./fixtures/server.py} --port-file port --certificate cert.pem --key key.pem > server.log 2>&1 &
        server=$!
        trap 'kill "$server" 2>/dev/null || true; wait "$server" 2>/dev/null || true' EXIT
        for attempt in $(seq 1 100); do if test -s port; then break; fi; sleep 0.05; done
        port=$(cat port)
        status=0
        curl --connect-timeout 5 --max-time 15 --silent --show-error "https://127.0.0.1:$port/" > rejected.txt 2> rejected.log || status=$?
        test "$status" = 60
        grep -q 'self-signed certificate' rejected.log
        curl --connect-timeout 5 --max-time 15 --silent --fail --cacert cert.pem "https://127.0.0.1:$port/"
      '';
      expected = "42";
      extraInputs = [
        package.tvp.deps.python
        package.tvp.deps.openssl
      ];
    };
  }
  // pkgs.lib.optionalAttrs (package ? testContext) {
    compiled-trust = {
      script = ''
        cc -Wall -Wextra -Werror -I${package}/include ${./fixtures/trust.c} -L${package}/lib -lcurl -o trust
        env -i ./trust
      '';
      expected = "${package.tvp.deps.ca-certificates}/etc/ssl/certs/ca-bundle.crt";
      extraInputs = [ package.tvp.cc ];
    };
    installed-provider = {
      script = ''
        test "$(pkg-config --modversion libcurl)" = ${package.version}
        test "$(curl-config --version)" = 'libcurl ${package.version}'
        test "$(head -n1 ${package}/bin/curl-config)" = '#!${package.specification.bash}/bin/bash'
        test "$(head -n1 ${package}/bin/wcurl)" = '#!${package.specification.bash}/bin/bash'
        test "$(curl-config --prefix)" = ${package}
        test -s ${package}/include/curl/curl.h
        test -s ${package}/lib/libcurl.la
        grep -Fx ${pkgs.lib.escapeShellArg "dependency_libs='' #pruned"} ${package}/lib/libcurl.la >&2
        test ! -e ${package}/lib/libcurl.a
        test "$(readlink ${package}/lib/libcurl.so)" = libcurl.so.4.8.0
        test "$(readlink ${package}/lib/libcurl.so.4)" = libcurl.so.4.8.0
        cc -Wall -Wextra -Werror ${./fixtures/consumer.c} $(pkg-config --cflags --libs libcurl) -o pkg-consumer
        cc -Wall -Wextra -Werror ${./fixtures/consumer.c} $(curl-config --cflags --libs) -o config-consumer
        test "$(env -i ./pkg-consumer)" = ${package.version}
        test "$(env -i ./config-consumer)" = ${package.version}
        env -i LD_DEBUG=libs ./pkg-consumer > /dev/null 2> loader
        grep -F 'calling init: ${package}/lib/libcurl.so.4' loader >&2
        grep -F 'calling init: ${package.tvp.deps.openssl}/lib/libssl.so' loader >&2
        grep -F 'calling init: ${package.tvp.deps.openssl}/lib/libcrypto.so' loader >&2
        grep -F 'calling init: ${package.tvp.deps.zlib}/lib/libz.so.1' loader >&2
        grep -F 'calling init: ${package.tvp.deps.zstd}/lib/libzstd.so.1' loader >&2
        grep -F 'calling init: ${package.tvp.deps.nghttp2}/lib/libnghttp2.so.14' loader >&2
        env -i LD_DEBUG=libs ${package}/bin/curl --version > version 2> cli-loader
        grep -F 'calling init: ${package}/lib/libcurl.so.4' cli-loader >&2
        grep -F 'OpenSSL/${package.tvp.deps.openssl.version}' version >&2
        grep -F 'zlib/${package.tvp.deps.zlib.version}' version >&2
        grep -F 'zstd/${package.tvp.deps.zstd.version}' version >&2
        grep -F 'nghttp2/${package.tvp.deps.nghttp2.version}' version >&2
        curl-config --features > features
        for feature in SSL HTTP2 libz zstd; do grep -x "$feature" features >&2; done
        if grep -E '^(HTTP3|IDN|PSL|brotli|GSS-API)$' features; then exit 1; fi
        curl-config --protocols > protocols
        for protocol in HTTP HTTPS FILE; do grep -x "$protocol" protocols >&2; done
        if grep -E '^(LDAP|LDAPS|SCP|SFTP)$' protocols; then exit 1; fi
        readelf -d ${package}/lib/libcurl.so.4.8.0 > dynamic
        for soname in libssl libcrypto libz.so libzstd libnghttp2; do grep -F "$soname" dynamic >&2; done
        grep -F 'Requires.private: zlib,libzstd,openssl,libnghttp2' ${package}/lib/pkgconfig/libcurl.pc >&2
        for provider in zlib libzstd openssl libnghttp2; do pkg-config --exists "$provider"; done
        printf installed-provider-ok
      '';
      expected = "installed-provider-ok";
      extraInputs = [
        package.tvp.cc
        package.tvp.deps.pkg-config
        package.tvp.deps.binutils
      ];
    };
  }
  // pkgs.lib.optionalAttrs (package.tvp.features.doCheck or false) {
    upstream = {
      script = ''
        test "$(cat ${package}/nix-support/upstream-tests.status)" = 0
        grep -F 'TESTDONE: 10 tests out of 10 reported OK' ${package}/nix-support/upstream-summary >&2
        printf upstream-10-ok
      '';
      expected = "upstream-10-ok";
    };
  };
}
