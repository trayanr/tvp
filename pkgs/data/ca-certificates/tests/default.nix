{
  pkgs,
  tvpLib,
  package,
  openssl,
}:
let
  mkSuite =
    if package ? testContext then
      args:
      package.testContext.mkSuite {
        inherit package;
        tests = builtins.mapAttrs (_: spec: {
          inherit (spec) script expected;
          tools = (spec.extraInputs or [ ]) ++ [ package.tvp.declaredTestDependencies.grep ];
        }) args.tests;
      }
    else
      tvpLib.tests.mkSuite;
in
mkSuite {
  inherit pkgs package;
  tests =
    {
      certificates = {
        script = ''
          openssl crl2pkcs7 -nocrl -certfile ${package}/etc/ssl/certs/ca-bundle.crt -out bundle.p7
          openssl pkcs7 -in bundle.p7 -print_certs > parsed.pem
          test "$(grep -c 'BEGIN CERTIFICATE' parsed.pem)" = "$(grep -c 'BEGIN CERTIFICATE' ${package}/etc/ssl/certs/ca-bundle.crt)"
          grep -q '^subject=' parsed.pem
          printf parsed
        '';
        expected = "parsed";
        extraInputs = [ openssl ];
      };
    }
    // pkgs.lib.optionalAttrs (package ? testContext) {
      data = {
        script = ''
          cmp ${package.src} ${package}/etc/ssl/certs/ca-bundle.crt
          test "$(sha256sum ${package.src} | cut -d' ' -f1)" = "$(sha256sum ${package}/etc/ssl/certs/ca-bundle.crt | cut -d' ' -f1)"
          test "$(find ${package} -type f -printf '%P\n' | sort)" = $'etc/ssl/certs/ca-bundle.crt\nnix-support/setup-hook'
          for mode in unset set empty; do
            (
              case "$mode" in
                unset) unset SSL_CERT_FILE NIX_SSL_CERT_FILE CURL_CA_BUNDLE;;
                set) export SSL_CERT_FILE=ssl NIX_SSL_CERT_FILE=nix CURL_CA_BUNDLE=curl;;
                empty) export SSL_CERT_FILE= NIX_SSL_CERT_FILE= CURL_CA_BUNDLE=;;
              esac
              source ${package}/nix-support/setup-hook
              if [[ "$mode" == set ]]; then
                test "$SSL_CERT_FILE:$NIX_SSL_CERT_FILE:$CURL_CA_BUNDLE" = ssl:nix:curl
              else
                test "$SSL_CERT_FILE" = ${package}/etc/ssl/certs/ca-bundle.crt
                test "$NIX_SSL_CERT_FILE" = "$SSL_CERT_FILE"
                test "$CURL_CA_BUNDLE" = "$SSL_CERT_FILE"
              fi
              ${package.specification.bash}/bin/bash -c 'test -n "$SSL_CERT_FILE" && test -n "$NIX_SSL_CERT_FILE" && test -n "$CURL_CA_BUNDLE"'
            )
          done
          printf data-ok
        '';
        expected = "data-ok";
        extraInputs = [
          package.tvp.declaredTestDependencies.findutils
          package.tvp.declaredTestDependencies.diffutils
        ];
      };
    };
}
