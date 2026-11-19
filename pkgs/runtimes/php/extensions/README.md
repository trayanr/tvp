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
The result supports the ordinary `.override`, `.edit`, `.editSteps` and
`.editRuntime` methods.

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

## Adding an extension to TVP

Follow the [ordinary package authoring guide](../../../../lib/NATIVE-RECIPES.md).
The extension's `default.nix` selects its builder, named package dependencies,
source and test suite. Use `deps` for build and runtime providers and
`testDeps` for fixtures such as a database server. Put package-specific
configure arguments and library wiring in the builder and read them from the
effective specification. The [ZIP definition](zip/default.nix) names `libzip`
and its [builder](zip/build.nix) uses `final.libzip`. Callers can replace it
with `php.extensions.zip.override { libzip = otherLibzip; }`.

Standalone extensions declare their version and source hashes. Bundled
extensions derive those from the corresponding PHP releases because the module
uses that release's source and SDK. The bundled release helper supplies that
mapping. The extension still declares its own builder, dependencies, tests and
compatibility policy.

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

Each declared pair has independent build and smoke results. Adding another
release does not inherit qualification from an earlier one. Adding a release means adding its source hash and explicit
PHP span to [redis/default.nix](redis/default.nix); the family shares the
[phpize builder](build-phpize.nix) and [installed tests](redis/tests.nix).

## Igbinary release selection

`php.extensions.igbinary` selects igbinary 3.2.17RC1 for PHP `>= 7.0`, `< 8.6`.
The upstream RC label is preserved in the version and exact attribute
`igbinary_3_2_17RC1`. Upstream’s [release](https://github.com/igbinary/igbinary/releases/tag/3.2.17RC1)
adds PHP 8.5 support; its [package metadata](https://github.com/igbinary/igbinary/blob/3.2.17RC1/package.xml)
requires PHP 7.0 or later. PHP 5 is outside this initial igbinary declaration.

```nix
tvp.packages.php_8_5.withExtensions {
  extensions = extensions: [ extensions.igbinary ];
}
```

The standalone serializer exposes `igbinary_serialize` and `igbinary_unserialize`.
Its checks load the selected module version, then roundtrip nested values,
embedded NUL bytes and distinct PHP scalar types. No server dependency is needed.
The family reuses the existing phpize builder and configured-runtime interface.

## Sybase and SQL Server

Use the `pdo_dblib` driver with FreeTDS on PHP 8.5:

```nix
tvp.packages.php_8_5.withExtensions {
  extensions = extensions: [ extensions.pdo_dblib ];
}
```

Each module uses the matching PHP release's `ext/pdo_dblib` source and links
against TVP's FreeTDS client library. Its checks verify PDO driver registration
and that a refused local connection produces the DB-Library error. A real Sybase
or SQL Server query needs a database instance. FreeTDS has separate checks for
the installed C library and `tsql` configuration.

## APCu

`php.extensions.apcu` selects APCu 5.1.28 for PHP `>= 7.0`, `< 8.6`.
The smoke checks load the module and exercise cache insert, lookup and removal.
To use the cache in a CLI process, enable `apc.enable_cli` explicitly:

```nix
tvp.packages.php_8_5.withExtensions {
  extensions = e: [ e.apcu ];
  settings."apc.enable_cli" = true;
}
```

## MongoDB

`php.extensions.mongodb` selects driver 2.5.7 on PHP 8.2 through 8.5.
Use `php.extensions.mongodb_1` for Composer projects requiring `ext-mongodb ^1`.
That selector provides driver 1.21.13 on PHP 8.1 through 8.5.
It includes OpenSSL TLS and zlib compression. Snappy, Zstandard, Cyrus SASL,
and client-side field-level encryption are disabled. The smoke checks load
the installed module, round-trip BSON, and construct a TLS client without a
database connection.

```nix
tvp.packages.php_8_2_35.withExtensions {
  extensions = e: [ e.mongodb_1 ];
}
```

## MySQL and MariaDB

`php.profiles.mysql` provides the current PHP with `mysqlnd`, `mysqli`, and
`pdo_mysql` in load order. The individual `php.profiles.mysqli` and
`php.profiles.pdo_mysql` profiles each include the required `mysqlnd` module.
All packaged PHP releases from 8.2 onward have matching MySQL module recipes.
To compose a pinned PHP release, select the modules in this order:

```nix
tvp.packages.php_8_5_0.withExtensions {
  extensions = e: [ e.mysqlnd e.mysqli e.pdo_mysql ];
}
```

The three modules use the selected PHP release's own source and SDK. The two
drivers use PHP's native client. Their tests execute a query over a private
Unix socket against a temporary MariaDB server from pinned Nixpkgs. A normal
PHP installation needs only the modules and a connection to your database.

## IMAP

`php.extensions.imap` uses each PHP 8.2–8.3 release's own IMAP source and SDK.
PHP moved IMAP to PECL in 8.4. TVP uses PECL IMAP 1.0.3 with the selected PHP
8.4 or 8.5 SDK. [PHP IMAP installation](https://www.php.net/manual/en/imap.installation.php)
[PECL IMAP 1.0.3](https://pecl.php.net/package/imap/1.0.3)

IMAP requires a non-thread-safe PHP build. It links TVP's UW c-client
with OpenSSL, with Kerberos disabled. Its installed checks load the expected
module version and read a message from a temporary local mailbox.

## OPcache

On PHP 8.2–8.4, select `e.opcache` in `withExtensions` to load the Zend module
built from that PHP release's source. When using Xdebug, list OPcache first.
PHP 8.5 always loads OPcache from the engine. Use `withExtensions` settings
to configure it, with `"opcache.enable_cli" = true` if you need caching in
CLI processes. The current `php.profiles.opcache` uses the built-in Zend module.
[PHP OPcache installation](https://www.php.net/opcache.installation)

The installed checks verify the Zend module version and compile a local PHP
fixture into the bytecode cache. Standard smoke testing also exercises the
built-in path on the current PHP 8.5 release.

## VR2 API

For VR2's PHP 8.2.35 and Composer MongoDB constraint, compose the API runtime
with the following extensions. The MySQL driver loads after `mysqlnd`.

```nix
tvp.packages.php_8_2_35.withExtensions {
  extensions = e: [
    e.bcmath
    e.calendar
    e.curl
    e.exif
    e.ftp
    e.gd
    e.gettext
    e.gmp
    e.mbstring
    e.zip
    e.intl
    e.pdo_pgsql
    e.pcntl
    e.sockets
    e.sysvsem
    e.mysqlnd
    e.pdo_mysql
    e.pdo_dblib
    e.sodium
    e.mongodb_1
  ];
}
```

BCMath and Calendar use the matching source for every packaged PHP release
from 8.2 onward. Their checks verify module versions, exact decimal arithmetic,
and Gregorian date conversion.

EXIF, FTP, PCNTL, Sockets and SysV semaphore support also use the matching
source and SDK for each packaged release from PHP 8.2 onward. EXIF can use
mbstring for optional multibyte decoding when both modules are loaded. FTP
links the matching PHP release's TVP OpenSSL provider and enables TLS with
`--with-openssl-dir` on PHP 8.2 and 8.3 or `--with-ftp-ssl` starting with PHP 8.4. Its installed
checks use a temporary loopback FTP fixture and perform an encrypted login
and command exchange. The OpenSSL CLI creates the fixture certificate during
testing.

GD, Gettext, GMP, and Sodium also use the matching source and SDK for every
packaged PHP release from 8.2 onward. GD uses PHP's bundled libgd with PNG,
JPEG, WebP, and FreeType. AVIF and XPM are disabled. The codec libraries and
libsodium are built from their upstream sources by TVP. libjpeg-turbo uses its
portable C implementation. Gettext uses the PHP base's GNU libc. The checks
verify the installed modules with small image round trips, message lookup in
the C locale, exact integer arithmetic, and a deterministic BLAKE2b digest.

The development shell can add `e.xdebug` for Xdebug 3.5.3 or
`e.xdebug_3_3_2` for the original pin on PHP 8.2 and 8.3.

## Checks and CI

`nix run .#upstream -- --list --php 8.2 php-mongodb` reports declared coverage
for a PHP series. It prints packaging gaps separately from source-backed hard
limits. Omit `--list` to also compare available upstream releases. See the
[repository tool documentation](../../../../tools/README.md) for the metadata
fields and bundled-module rules.

The Redis module has two focused installed checks: load it and read its version, then
connect to a temporary Redis server over a Unix socket and perform SET/GET. No
TCP port or existing host service is used. `tvp.packages.redis` supplies that
test server; PHPRedis does not require the Redis server to compile or load.

The [Redis server package](../../../servers/redis/README.md) has its own version
and Unix-socket roundtrip checks. These checks do not run either project's full
upstream suite.

Standard `nix run .#test -- all` and CI include every declared compatible
PHP/module pair, with these two small checks for each pair. Full upstream
regression suites remain separate under [TESTING.md](../../../../TESTING.md).
Local iteration can select one pair and reuse exact passing results. A source
evaluation or a passing current pair does not qualify the historical matrix.

The catalogue includes every declared extension release for each PHP version
inside that release's compatibility span. Per-family counts and unsupported
engines are available in
`php.metadata.families`; incompatible combinations are excluded rather than
attempted.

Inspect the declarations or select the execution scope:

```sh
nix eval --json .#php.metadata
# Standard testing / CI: all compatible pairs plus the other smoke subjects.
nix run .#test -- all
# Local iteration: only one pair from that standard plan.
nix run .#test -- all --only php_8_5_12--redis_6_3_0
# One pair: build the module and run its two small checks.
nix build .#php.extensionTests.php_8_5_12--redis_6_3_0
# PHP extension matrix subset.
nix build .#php.extensionTestsAll
# Ready-to-run current PHP with Redis:
nix run .#php.profiles.redis -- -r 'echo phpversion("redis"), PHP_EOL;'
```

`php.extensionPackages` contains the module build targets;
`php.extensionTests` contains the corresponding two-check batches. Standard CI
includes every one of these batches alongside the representative checks in
[`tests/smoke.nix`](../../../../tests/smoke.nix).

Both standard CI and `extensionTestsAll` may compile historical PHP engines and
extensions that are not cached. They reuse valid outputs and run only the two
installed checks per pair; they do not run full PHP, Redis or PHPRedis upstream
suites. The metadata describes the declared jobs; execution receipts record
which exact builds and checks have passed.
