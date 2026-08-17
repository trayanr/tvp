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
in
tvpLib.tests.mkSuite {
  inherit pkgs;
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
