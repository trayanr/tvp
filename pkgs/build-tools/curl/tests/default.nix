{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''curl --version | awk 'NR==1 {print $2}' '';
      expected = package.version;
    };
    library = {
      script = ''cc -I${package}/include ${./fixtures/consumer.c} -L${package}/lib -lcurl -o consumer; ./consumer'';
      expected = package.version;
      extraInputs = [ package.tvp.cc ];
    };
    trust = {
      script = ''curl-config --ca'';
      expected = "${package.tvp.deps.ca-certificates}/etc/ssl/certs/ca-bundle.crt";
    };
    http = {
      script = ''
        printf 42 | zstd -q -o body.zst
        python3 ${./fixtures/server.py} --port-file port --zstd body.zst > server.log 2>&1 &
        server=$!
        trap 'kill "$server"; wait "$server" || true' EXIT
        for attempt in $(seq 1 100); do if test -s port; then break; fi; sleep 0.05; done
        port=$(cat port)
        curl --silent --fail --compressed "http://127.0.0.1:$port/gzip" > gzip.txt
        test "$(cat gzip.txt)" = 42
        curl --silent --fail --compressed "http://127.0.0.1:$port/zstd"
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
        trap 'kill "$server"; wait "$server" || true' EXIT
        for attempt in $(seq 1 100); do if test -s port; then break; fi; sleep 0.05; done
        port=$(cat port)
        status=0
        curl --silent --show-error "https://127.0.0.1:$port/" > rejected.txt 2> rejected.log || status=$?
        test "$status" = 60
        grep -q 'self-signed certificate' rejected.log
        curl --silent --fail --cacert cert.pem "https://127.0.0.1:$port/"
      '';
      expected = "42";
      extraInputs = [
        package.tvp.deps.python
        package.tvp.deps.openssl
      ];
    };
  };
}
