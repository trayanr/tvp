{ package, context, ... }:
context.mkSuite {
  inherit package;
  libraries = [ package ];
  tests = {
    cli = {
      script = ''
        actual=$(${package}/bin/keyctl --version)
        [[ "$actual" == "keyctl from keyutils-${package.version} (Built "*")" ]]
        test -x "${package}/sbin/request-key"
        test -x "${package}/sbin/key.dns_resolver"
        printf '%s\n' keyutils-cli-ok
      '';
      expected = "keyutils-cli-ok";
    };
    consumer = {
      tools = [ package.specification.base.tools.pkg-config ];
      script = ''
        test "$(pkg-config --variable=prefix libkeyutils)" = "${package}"
        "$CC" ${./consumer.c} $(pkg-config --cflags --libs libkeyutils) -o consumer
        ./consumer
      '';
      expected = "keyutils-${package.version}";
    };
  };
}
