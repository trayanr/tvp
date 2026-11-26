{ package, context, ... }:
context.mkSuite {
  inherit package;
  tests = {
    version = {
      script = ''
        export COMPOSER_HOME="$PWD/composer-home"
        output=$(composer --no-ansi --version)
        read -r program label version _ <<< "$output"
        test "$program $label" = "Composer version"
        printf '%s\n' "$version"
      '';
      expected = package.version;
    };
    offline-resolution = {
      tools = [ package.tvp.declaredTestDependencies.zip ];
      script = ''
        export HOME="$PWD" COMPOSER_HOME="$PWD/composer-home"
        export COMPOSER_CACHE_DIR="$PWD/cache"
        # Composer 2.7 also blocks local ZIP reads when this is set.
        # The fixture defines only a local archive and disables Packagist.
        unset COMPOSER_DISABLE_NETWORK
        cp ${./Message.php} Message.php
        zip -q fixture.zip Message.php
        mkdir project
        cd project
        cp ${./composer.json} composer.json
        composer update --no-interaction --no-plugins --no-scripts --no-audit --no-progress >&2
        ${package.runtime.php}/bin/php ${./verify.php}
      '';
      expected = "local dependency loaded";
    };
  };
}
