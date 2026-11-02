{
  pkgs,
  tvp,
  ruby,
}:
{
  runtime-expectation = import ../../../../lib/runtime-expectation.nix { inherit (pkgs) lib; } {
    package = ruby;
    stdenv = ruby.stdenv;
    python = ruby.tvp.deps.python;
  };
}
// tvp.lib.tests.mkSuite {
  inherit pkgs;
  package = ruby;
  tests = {
    launchers = {
      script = ''
        ${ruby.tvp.deps.coreutils}/bin/env -i HOME="$TMPDIR" ${ruby}/bin/bundle --version >&2
        ${ruby.tvp.deps.coreutils}/bin/env -i HOME="$TMPDIR" ${ruby}/${ruby.gemPath}/gems/bundler-4.0.16/exe/bundle --version >&2
        ${ruby.tvp.deps.coreutils}/bin/env -i HOME="$TMPDIR" ${ruby}/${ruby.gemPath}/gems/rake-13.3.1/exe/rake --version >&2
        # This upstream CLI prints help then exits 1; require both observations.
        if ${ruby.tvp.deps.coreutils}/bin/env -i HOME="$TMPDIR" ${ruby}/${ruby.gemPath}/gems/minitest-6.0.0/bin/minitest --help > minitest-help 2>&1; then
          exit 1
        else
          test "$?" = 1
        fi
        grep -F 'Usage: rake test' minitest-help >&2
        printf selected
      '';
      expected = "selected";
    };
    consumer-discovery = {
      script = ''
        unset GEM_PATH RUBYLIB
        addToSearchPath() { export "$1=''${!1:+''${!1}:}$2"; }
        addEnvHooks() { "$2" ${ruby}; }
        source ${ruby}/nix-support/setup-hook
        test "$GEM_PATH" = '${ruby}/${ruby.gemPath}'
        test "$RUBYLIB" = '${ruby}/lib/ruby/site_ruby:${ruby}/lib/ruby/site_ruby/${ruby.libDir}:${ruby}/lib/ruby/site_ruby/${ruby.libDir}/${ruby.stdenv.targetPlatform.system}'
        ruby -rrubygems -e 'abort unless Gem.path.include?(ARGV[0]); print "discovered"' "$GEM_PATH"
      '';
      expected = "discovered";
    };
  };
}
