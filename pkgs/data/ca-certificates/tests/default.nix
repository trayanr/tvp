{
  pkgs,
  tvpLib,
  package,
  openssl,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests.certificates = {
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
