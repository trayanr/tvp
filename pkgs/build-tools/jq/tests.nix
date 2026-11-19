{ package, context, ... }:
context.mkSuite {
  inherit package;
  tests = {
    version = {
      libraries = [ package ];
      tools = [ package.specification.base.tools.pkg-config ];
      script = ''
        test "$(pkg-config --variable=prefix libjq)" = "${package}"
        test "$(pkg-config --modversion libjq)" = "${package.version}"
        jq --version
      '';
      expected = "jq-${package.version}";
    };
    filter = {
      script = ''
        printf '%s\n' '{"items":[{"active":true,"name":"beta"},{"active":false,"name":"skip"},{"active":true,"name":"alpha"}]}' |
          jq -ce '[.items[] | select(.active) | .name] | sort'
      '';
      expected = ''["alpha","beta"]'';
    };
    regex = {
      script = ''
        jq -ne --arg text 'é猫' '$text | test("^é.$") and (test("^[a-z]+$") | not)'
      '';
      expected = "true";
    };
  };
}
