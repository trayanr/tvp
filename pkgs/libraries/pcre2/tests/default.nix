{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
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
    // import ./consumers.nix { inherit pkgs package; }
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
          "printf '%s' " + pkgs.lib.escapeShellArg (builtins.toJSON (map upstream.normalise tags));
        expected = ''["10.00","10.49",null,null,null,null,null,null,null,null,null,null]'';
      };
    };
}
