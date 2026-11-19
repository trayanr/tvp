{ package, context, ... }:
context.mkSuite {
  inherit package;
  tests = {
    version = {
      script = "${package}/bin/nixfmt --version";
      expected = "nixfmt ${package.version}";
    };
    format = {
      script = ''
        printf '%s\n' '{x=1; y = [1 2];}' > example.nix
        status=0
        ${package}/bin/nixfmt --check example.nix >&2 || status=$?
        test "$status" -eq 1
        ${package}/bin/nixfmt example.nix
        ${package}/bin/nixfmt --check example.nix >&2
        cat example.nix
      '';
      expected = ''
        {
          x = 1;
          y = [
            1
            2
          ];
        }'';
    };
  };
}
