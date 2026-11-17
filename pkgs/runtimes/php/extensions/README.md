# PHP extensions

Select the PHP engine first, then select extensions from its catalogue:

```nix
tvp.packages.php_8_5.withExtensions {
  extensions = extensions: [ extensions.redis ];
  settings.memory_limit = "128M";
}
```

`php_8_5` follows the latest packaged PHP 8.5 release. Use `php_8_5_12` to pin
the engine exactly. Inside the callback, `redis` selects the newest declared
compatible PHPRedis release; `redis_6_3_0` pins that extension exactly. Extension
packages are also accessible directly as `php_8_5.extensions.redis`.

Each module is built with the selected engine's `phpize`, headers and
`php-config`. Loading a module built for a different PHP derivation is rejected
during evaluation. This also covers PHP builds with different configuration,
not just different version numbers. Rebind a standalone module explicitly with
`.override { php = tvp.packages.php_8_2; }` when needed; selecting it through the
engine's catalogue usually expresses the intent more clearly.

The engine, compiled extension and configured runtime have separate producers.
Changing INI settings or the selected extension list reuses the engine and
unchanged module outputs. The runtime writes its own `php.ini` and controls the
INI scan directory; it does not modify the PHP package or use host configuration.
Declare module loaders through `extensions`, rather than INI `extension`,
`zend_extension` or `extension_dir` settings. The configured CLI commands use
this configuration; applications embedding PHP need to select configuration
through their own interface.

## Redis release selection

The initial catalogue declares these spans:

| PHPRedis | PHP versions | Basis |
| --- | --- | --- |
| 2.2.8 | `>= 5.2`, `< 6.0` | Upstream release requirements. |
| 4.3.0 | `>= 5.3`, `< 7.4` | Conservative span following upstream CI. |
| 6.0.2 | `>= 7.2`, `< 8.3` | Conservative span following upstream CI. |
| 6.3.0 | `>= 7.4`, `< 8.6` | Upstream PHP 7.4–8.5 coverage, including its PHP 8.5 fix. |

These are compatibility declarations, not a claim that every pair has been
built on Tower. PHP 5.0 and 5.1 have no declared compatible Redis release in this
initial selection. Selecting an incompatible exact extension version fails
during evaluation. Optional igbinary, msgpack and compression integrations are
not enabled in the initial Redis module.

PHP 8.5.12 / PHPRedis 6.3.0 passes both local smoke checks, using Redis 8.10.3.
Historical pairs remain unqualified until their individual build and
smoke checks pass. Adding a release means adding its source hash and explicit
PHP span to [redis/default.nix](redis/default.nix); the family shares the
[phpize builder](build-phpize.nix) and [installed tests](redis/tests.nix).

## Checks and CI

The module has two focused installed checks: load it and read its version, then
connect to a temporary Redis server over a Unix socket and perform SET/GET. No
TCP port or existing host service is used. `tvp.packages.redis` supplies that
test server; PHPRedis does not require the Redis server to compile or load.

The [Redis server package](../../../servers/redis/README.md) has its own version
and Unix-socket roundtrip checks. These checks do not run either project's full
upstream suite.

Compatibility CI should build each explicitly declared PHP/module pair and run
these small checks. Keep that matrix distinct from a normal local change,
which generally checks the current pair and reuses exact passing results.
Building every declared pair or running full upstream regressions is an
explicit action under [TESTING.md](../../../../TESTING.md). A source evaluation
or a passing current pair does not qualify the historical matrix.

The catalogue exposes 296 declared pairs across the 190 packaged PHP versions.
PHP 5.0 and 5.1 are listed as unsupported. Inspect the declarations or build
one pair explicitly:

```sh
nix eval --json .#php.metadata
nix build .#php.extensionTests.php_8_5_12--redis_6_3_0
# Ready-to-run current PHP with Redis:
nix run .#php.profiles.redis -- -r 'echo phpversion("redis"), PHP_EOL;'
```

`php.extensionPackages` contains the module build targets;
`php.extensionTests` contains the corresponding two-check batches. CI can
enumerate these attributes without inventing incompatible combinations. They
are explicit matrix targets; normal CI adds only the current module's two
checks and the server's two checks to the existing smoke selection.
