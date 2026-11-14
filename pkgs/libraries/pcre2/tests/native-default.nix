{
  pkgs,
  tvpLib,
  package,
}:
package.testContext.mkSuite {
  inherit package;
  tools = package.specification.environment.tools ++ [ package.tvp.deps.binutils ];
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
    // import ./native-consumers.nix { inherit pkgs package; }
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

// import ./native-contract.nix {
  inherit package;
  lib = pkgs.lib;
}

// (
  if
    (package ? specification)
    && (package.specification ? upstreamPlan)
    && (package.specification.upstreamCheck.enabled or true)
  then
    {
      # Independent native upstream registration.
      upstream = import ../native/upstream.nix { package = package; };
    }
  else
    { }
)
