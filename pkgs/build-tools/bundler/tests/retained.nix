# One suite, shared by every bundler version. Never fork it per builder: a test
# that exists only for newer versions cannot detect drift in an older one.
# Guards select whole tests; they never edit a test body.
{
  pkgs,
  tvpLib,
  bundler,
}:
let
  inherit (bundler.passthru.tvp) deps;
  owned = bundler ? testContext;
  suite =
    args:
    if !owned then
      tvpLib.tests.mkSuite (args // { inherit pkgs; })
    else
      bundler.testContext.mkSuite (
        args
        // {
          tools =
            bundler.specification.environment.tools
            ++ (with (import ../../../../bases/source-gnu { }).tools; [
              make
              grep
              sed
              gawk
              diffutils
            ]);
          libraries = [ bundler ];
          tests = builtins.mapAttrs (
            _: test:
            (builtins.removeAttrs test [ "extraInputs" ])
            // pkgs.lib.optionalAttrs (test ? extraInputs) {
              tools =
                test.extraInputs
                ++ (with (import ../../../../bases/source-gnu { }).tools; [
                  make
                  grep
                  sed
                  gawk
                  diffutils
                ]);
            }
          ) args.tests;
        }
      );
in
suite {
  package = bundler;

  tests = {
    # The version bundler reports, not the version the package claims. Ruby
    # ships bundler as a default gem, so a wrapper that resolves by name rather
    # than by version silently yields the interpreter's bundler instead.
    # GEM_PATH is unset deliberately: the build sandbox sets it, and that masks
    # a wrapper resolving bundler by name instead of by version — which is how
    # a user running `nix shell` gets the interpreter's default bundler instead
    # of this one. HOME must be writable or bundler warns on stdout, and the
    # line is matched rather than positional for the same reason.
    version = {
      script = ''
        export HOME=$PWD
        unset GEM_PATH GEM_HOME RUBYLIB
        bundle --version | awk '/^Bundler version/ { print $3 }'
      '';
      expected = bundler.version;
    };

    ruby = {
      script = ''
        head -1 "$(command -v bundle)" | sed 's|^#!||'
      '';
      expected = "${deps.ruby}/bin/ruby";
    };
  };
}
