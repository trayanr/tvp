# One suite, shared by every bundler version. Never fork it per builder: a test
# that exists only for newer versions cannot detect drift in an older one.
# Guards select whole tests; they never edit a test body.
{
  pkgs,
  tvpLib,
  package,
  tvp,
}:
let
  bundler = package;
  deps = {
    ruby = bundler.runtime.ruby;
  };
in
package.testContext.mkSuite {
  inherit package;
  tools =
    package.specification.environment.tools
    ++ [ package.tvp.cc.bintools ]
    ++ (with (import ../../../../bases/source-gnu { }).tools; [
      grep
      sed
      gawk
      diffutils
    ]);
  libraries = [ package ];

  tests = {
    # The version bundler reports, not the version the package claims. Ruby
    # ships bundler as a default gem, so a wrapper that resolves by name rather
    # than by version silently yields the interpreter's bundler instead.
    # GEM_PATH is unset deliberately: the build sandbox sets it, and that masks
    # a wrapper resolving bundler by name instead of by version — which is how
    # a user running `nix shell` gets the interpreter's default bundler instead
    # of this one. HOME must be writable or bundler warns on stdout, and the
    # line is matched rather than positional for the same reason.
    offline = {
      script = ''
        trap 'for log in ./*.log; do if test -f "$log"; then cat "$log" >&2; fi; done' EXIT
        export PATH=${bundler}/bin:${deps.ruby}/bin:${package.specification.coreutils}/bin
        export HOME="$PWD/home"
        mkdir -p "$HOME" vendor/cache fixture/lib
        unset GEM_PATH GEM_HOME RUBYLIB
        printf 'module TvpOffline; ANSWER = 42; end\n' > fixture/lib/tvp_offline.rb
        cat > fixture/tvp-offline.gemspec <<'SPEC'
        Gem::Specification.new do |s|
          s.name = 'tvp-offline'; s.version = '1.0.0'; s.summary = 'Offline fixture'
          s.authors = ['TVP']; s.files = ['lib/tvp_offline.rb']
        end
        SPEC
        cd fixture
        gem build tvp-offline.gemspec > ../gem.log 2>&1
        cd ..
        cp fixture/tvp-offline-1.0.0.gem vendor/cache/
        printf "source 'https://invalid.example'\ngem 'tvp-offline', '= 1.0.0'\n" > Gemfile
        bundle --version > version
        test "$(cat version)" = 'Bundler version ${bundler.version}'
        bundle config set --local path vendor/bundle > config.log 2>&1
        bundle install --local > install.log 2>&1
        bundle lock --local > lock.log 2>&1
        bundle check > check.log 2>&1
        bundle exec ruby -rbundler -rtvp_offline -e '
          abort unless Bundler::VERSION == ARGV[0] && TvpOffline::ANSWER == 42
          abort unless Gem.loaded_specs["bundler"].full_gem_path.start_with?(ARGV[1])
          abort unless Gem.loaded_specs["tvp-offline"].full_gem_path.start_with?(ARGV[2])
          print "offline-ok"
        ' ${bundler.version} ${bundler} "$PWD/vendor/bundle" > exec.log 2>&1
        cat exec.log
        printf "gem 'tvp-missing-offline', '= 0.0.1'\n" >> Gemfile
        if bundle install --local > failure.log 2>&1; then
          cat failure.log >&2
          exit 1
        else
          status=$?
          printf 'missing-gem exit=%s\n' "$status" >&2
          test "$status" = 7
        fi
        cat gem.log config.log install.log lock.log check.log failure.log >&2
      '';
      expected = "offline-ok";
    };
    version = {
      script = ''
        export HOME=$PWD
        unset GEM_PATH GEM_HOME RUBYLIB
        bundle --version > version
        awk '/^Bundler version/ { print $3 }' version
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

// {
  owned-customization = import ./owned-contracts.nix { inherit pkgs tvp package; };
}
