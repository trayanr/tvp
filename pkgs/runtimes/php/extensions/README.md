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
not just different version numbers. To target another engine within a module's
declared compatibility range, rebind it with
`.override { php = tvp.packages.php_8_2; }`; selecting it through the engine's
catalogue usually expresses the intent more clearly.

The engine, compiled extension and configured runtime have separate producers.
Changing INI settings or the selected extension list reuses the engine and
unchanged module outputs. The runtime writes its own `php.ini` and controls the
INI scan directory; it does not modify the PHP package or use host configuration.
Declare module loaders through `extensions`, rather than INI `extension`,
`zend_extension` or `extension_dir` settings. The configured CLI commands use
this configuration; applications embedding PHP need to select configuration
through their own interface.

## Building your own extension

Use the selected engine's `buildExtension` function for a standalone phpize
extension, then compose it like any packaged module:

```nix
let
  php = tvp.packages.php_8_5;
  custom = php.buildExtension {
    name = "my_extension";
    version = "1.0.0";
    src = ./my-extension;
    configureOptions = [ "--enable-my-extension" ];
  };
in
php.withExtensions {
  extensions = e: [ e.redis custom ];
}
```

`src` can be a source directory or an archive; archives use gzip by default,
with `compression = "xz"` or `"bzip2"` available. The function selects PHP's
installed SDK, the matching base and the Autotools providers. Additional native
libraries go in `libraries`; `loader = "zend_extension"` selects a Zend loader
instead of the default `"extension"`. `meta` supplies package metadata.
The result supports the ordinary `.override`, `.edit` and `.editSteps` methods.

Without `phpCompatibility`, the builder records the selected PHP version as an
exact compatibility declaration. That declaration stays in place after an
override; changing only `php` rejects a different PHP version. Declare broader
support explicitly when rebinding:

```nix
custom.override {
  php = tvp.packages.php_8_2;
  phpCompatibility = { min = "8.2"; before = "8.6"; };
}
```

The range describes your source's intended compatibility; it is not evidence
that those PHP versions have been tested. Optional `tests` and `testDeps` use
the same installed-test factory and dependency conventions as extension
families. A standalone custom extension is not automatically added to the
repository's version matrix. Use
`tvp.lib.php.mkExtensionFamily` and a release table for a versioned family.

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

Standard `nix run .#test -- start` and CI include every declared compatible
PHP/module pair, with these two small checks for each pair. Full upstream
regression suites remain separate under [TESTING.md](../../../../TESTING.md).
Local iteration can select one pair and reuse exact passing results. A source
evaluation or a passing current pair does not qualify the historical matrix.

The catalogue exposes 296 declared compatible pairs across the 190 packaged PHP
versions, with two named checks per pair: 592 checks. It includes every declared
extension release for each PHP version inside that release's compatibility
span. PHP 5.0 and 5.1 are listed as unsupported; incompatible combinations are
excluded rather than attempted.

Inspect the declarations or select the execution scope:

```sh
nix eval --json .#php.metadata
# Standard testing / CI: all compatible pairs plus the other smoke subjects.
nix run .#test -- start
# Local iteration: only one pair from that standard plan.
nix run .#test -- start --only php_8_5_12--redis_6_3_0
# One pair: build the module and run its two small checks.
nix build .#php.extensionTests.php_8_5_12--redis_6_3_0
# PHP extension matrix subset: all 296 pairs / 592 checks, no other subjects.
nix build .#php.extensionTestsAll
# Ready-to-run current PHP with Redis:
nix run .#php.profiles.redis -- -r 'echo phpversion("redis"), PHP_EOL;'
```

`php.extensionPackages` contains the module build targets;
`php.extensionTests` contains the corresponding two-check batches. Standard CI
includes every one of these batches, without inventing incompatible
combinations. The full selection contains 606 named checks across 303 subjects:
592 from this matrix and 14 across the four compiler bases, Perl, Ruby and Redis.

Both standard CI and `extensionTestsAll` may compile historical PHP engines and
extensions that are not cached. They reuse valid outputs and run only the two
installed checks per pair; they do not run full PHP, Redis or PHPRedis upstream
suites. The historical matrix has not been executed locally yet; its pairs
remain unqualified until their actual build and test results pass.
