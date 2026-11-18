{ tvp }:
{
  package,
  lib,
  context,
}:
let
  runtime = import ../../with-extensions.nix {
    inherit lib tvp;
    php = package.php;
    extensions = [ package ];
  };
  php = "${runtime}/bin/php";
  openssl = package.tvp.declaredTestDependencies.opensslCli;
in
context.mkSuite {
  inherit package;
  tools = [ runtime ];
  tests = {
    load = {
      script = ''
        ${php} -r '
          if (!function_exists("ftp_ssl_connect")) {
            throw new RuntimeException("FTP TLS support is missing");
          }
          echo phpversion("ftp");
        '
      '';
      expected = package.version;
    };
    roundtrip = {
      tools = [
        runtime
        openssl
      ];
      script = ''
        printf '[req]\ndistinguished_name=dn\n[dn]\n' > openssl.cnf
        ${lib.getBin openssl}/bin/openssl req -x509 -newkey rsa:2048 -noenc \
          -config openssl.cnf -subj /CN=localhost -days 1 -keyout key.pem -out cert.pem >&2
        ${php} ${./loopback.php} ${php}
      '';
      expected = "200 TVP FTPS fixture";
    };
  };
}
