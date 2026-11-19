{ package, context, ... }:
context.mkSuite {
  inherit package;
  libraries = [ package ];
  tests = {
    sdk = {
      tools = [ package.specification.base.tools.pkg-config ];
      script = ''
        test "$(${package}/bin/krb5-config --prefix)" = "${package}"
        test "$(pkg-config --variable=prefix krb5-gssapi)" = "${package}"
        ${package}/bin/krb5-config --version
      '';
      expected = "Kerberos 5 release ${package.version}";
    };
    gssapi = {
      tools = [ package.specification.base.tools.pkg-config ];
      script = ''
        printf '%s\n' '[libdefaults]' ' default_realm = EXAMPLE.COM' > krb5.conf
        export KRB5_CONFIG="$PWD/krb5.conf"
        "$CC" ${./consumer.c} $(pkg-config --cflags --libs krb5 krb5-gssapi) -o consumer
        ./consumer
      '';
      expected = "tvp@EXAMPLE.COM";
    };
  };
}
