{
  package,
  lib,
  context,
}:
context.mkSuite {
  inherit package;
  tools = package.specification.environment.tools ++ [ package.specification.base.compiler.bintools ];
  tests =
    {
      version = {
        script = ''
          ${package}/bin/pcre2grep --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
        '';
        expected = package.version;
      };
      operation = {
        script = ''
          printf 'preserved-42\n' | ${package}/bin/pcre2grep -o '[a-z]+(?=-[0-9]+)'
        '';
        expected = "preserved";
      };
    }
    // import ./installed-consumers.nix { inherit package lib context; }
    // {
      upstream-tags = {
        script =
          let
            upstream = import ../upstream.nix;
            tags = [
              "pcre2-10.00"
              "pcre2-10.49"
              "pcre2-10.49-RC1"
              "pcre2-10.50-dev"
              "pcre2-10.49^{}"
              "pcre2-10.49extra"
              "prefix-pcre2-10.49"
              "v10.49"
              "pcre2-10.49.1"
              "pcre2-10x49"
              "pcre2-10"
              ""
            ];
          in
          "printf '%s' " + lib.escapeShellArg (builtins.toJSON (map upstream.normalise tags));
        expected = ''["10.00","10.49",null,null,null,null,null,null,null,null,null,null]'';
      };
    };
}

// import ./installed-contract.nix { inherit package lib context; }

// lib.optionalAttrs package.specification.doCheck {
  upstream = import ./upstream.nix { inherit package lib context; };
}
