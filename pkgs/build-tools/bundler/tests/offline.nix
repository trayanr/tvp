{
  package,
  lib,
  context,
}:
let
  bundler = package;
  deps.ruby = package.runtime.ruby;
  tools = (
    builtins.removeAttrs package.specification.base.tools [
      "gcc"
      "bash"
      "coreutils"
      "binutils"
    ]
  );
in
(context.mkSuite {
  inherit package;
  tools = [
    tools.grep
    tools.sed
    tools.gawk
    tools.diffutils
  ];
  libraries = [ package ];
  tests.offline = {
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
})
// {
  owned-customization = import ./owned-contracts.nix { inherit package lib context; };
}
