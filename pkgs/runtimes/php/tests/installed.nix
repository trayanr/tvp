# Shared installed assertions for all 190 ordinary PHP releases.
{
  package,
  lib,
  context,
}:
let
  php = package;
  deps = package.tvp.deps;
  tools = package.specification.base.tools;
  runtimeProvider =
    dependency:
    let
      matches = builtins.filter (p: p.pname == dependency.pname) package.specification.runtime.libraries;
    in
    if builtins.length matches == 1 then
      builtins.head matches
    else
      throw "PHP: expected one runtime provider for ${dependency.pname}";
  suite =
    args:
    context.mkSuite {
      inherit package;
      libraries = [ package ];
      tools = package.specification.environment.tools ++ [ package.specification.base.compiler.bintools ];
      tests = builtins.mapAttrs (
        _: spec:
        (builtins.removeAttrs spec [ "extraInputs" ])
        // lib.optionalAttrs (spec ? extraInputs) {
          tools = package.specification.environment.tools ++ spec.extraInputs;
        }
      ) args.tests;
    };
  consumerStandard = php.tvp.features.consumerCStandard or null;
  configureEnv = lib.optionalString (
    consumerStandard != null
  ) "CFLAGS=\"\${CFLAGS:--g -O2} -std=${consumerStandard}\" ";

  # sha256("tvp"), first 16 hex characters.
  tvpDigest = "f6f6ead0bd85c312";
  linkage = dependency: soname: {
    script = ''
      paths=$(LD_TRACE_LOADED_OBJECTS=1 "${php}/bin/php" | awk '/${soname}/ { print $3 }')
      test -n "$paths"
      while IFS= read -r path; do
        case "$path" in
          ${lib.escapeShellArg "${lib.getLib (runtimeProvider dependency)}/"}*) ;;
          *) echo "Unexpected library path: $path" >&2; exit 1 ;;
        esac
      done <<< "$paths"
      printf linked
    '';
    expected = "linked";
    extraInputs = [ ];
  };
in
suite {
  tests =
    {
      version = {
        script = ''
          php -r 'echo PHP_VERSION;'
        '';
        expected = php.version;
      };

      cgi = {
        script = "php-cgi -q ${./fixtures/cgi.php} ";
        expected = php.version;
      };

      core = {
        script = ''
          php -r '$seen = array(); foreach (array("tvp", "nix", "tvp", "preserves", "nix") as $w) { $seen[$w] = true; } echo implode(" ", array_keys($seen));'
        '';
        expected = "tvp nix preserves";
      };

      # Exercise successful and rejected conversions after the native iconv probes.
      iconv = {
        script = "php ${./fixtures/iconv.php}";
        expected =
          "converted\n"
          + (if php.tvp.features.iconvPartialOutputOnError or false then "string::1" else "boolean:false:1");
      };

      # ext/dom and ext/simplexml are built by default and silently absent when
      # libxml2 is not found, so a green build alone does not prove them.
      xml = {
        script = ''
          php -r '$d = new DOMDocument(); $d->loadXML("<a><b>tvp</b></a>"); echo $d->getElementsByTagName("b")->item(0)->textContent;'
        '';
        expected = "tvp";
      };
    }

    // lib.optionalAttrs (builtins.compareVersions php.version "5.3.0" >= 0) {
      phar-helper = import ./installed-phar.nix { inherit package lib context; };
    }

    # phpize, php-config and installed headers have a separate install path.
    // lib.optionalAttrs php.tvp.features.functionEntryEnd {
      compile = {
        script = ''
          mkdir -p ext && cd ext
          cp ${./fixtures/ext-config.m4} config.m4
          cp ${./fixtures/ext-tvp.c} tvp.c
          phpize > /dev/null
          ${configureEnv}./configure --with-php-config="$(command -v php-config)" > /dev/null
          make > /dev/null
          php -d extension="$PWD/modules/tvp.so" -r 'echo tvp_answer();'
        '';
        expected = "42";
        extraInputs = [
          package.tvp.declaredTestDependencies.autoconf
          package.tvp.declaredTestDependencies.automake
          package.tvp.declaredTestDependencies.libtool
          tools.gnumake
        ];
      };
    }
    // lib.optionalAttrs (!php.tvp.features.functionEntryEnd) {
      compile-legacy = {
        script = ''
          mkdir -p ext && cd ext
          cp ${./fixtures/ext-config.m4} config.m4
          cp ${./fixtures/ext-tvp-legacy.c} tvp.c
          phpize > /dev/null
          ${configureEnv}./configure --with-php-config="$(command -v php-config)" > /dev/null
          make > /dev/null
          printf 'extension_dir="%s"\nextension=tvp.so\n' "$PWD/modules" > php.ini
          php -c "$PWD/php.ini" -r 'echo tvp_answer();'
        '';
        expected = "42";
        extraInputs = [
          package.tvp.declaredTestDependencies.autoconf
          package.tvp.declaredTestDependencies.automake
          package.tvp.declaredTestDependencies.libtool
          tools.gnumake
        ];
      };
    }

    // lib.optionalAttrs php.tvp.features.shortArraySyntax {
      script = {
        script = ''
          cp ${./fixtures/script.php} script.php
          php script.php
        '';
        expected = "tvp nix preserves";
      };
    }

    // lib.optionalAttrs php.tvp.features.passwordApi {
      password = {
        script = ''
          php -r '$h = password_hash("tvp", PASSWORD_BCRYPT); echo password_verify("tvp", $h) && !password_verify("wrong", $h) ? "verified" : "failed";'
        '';
        expected = "verified";
      };
    }

    // lib.optionalAttrs (deps ? openssl) {
      # Fixed, public test keys exercise the crypto API without depending on a
      # host openssl.cnf or newer key-introspection interfaces.
      openssl-rsa = {
        script = ''
          php -r '$public = file_get_contents("${./fixtures/rsa-public.pem}"); $private = file_get_contents("${./fixtures/rsa-private.pem}"); if (!openssl_public_encrypt("tvp", $encrypted, $public) || !openssl_private_decrypt($encrypted, $plain, $private)) { exit(1); } echo $plain;'
        '';
        expected = "tvp";
      };

      openssl-linkage = {
        script = ''
          LD_TRACE_LOADED_OBJECTS=1 "${php}/bin/php" | awk '/libssl\.so/ { print $3 }' | grep -q "^${(runtimeProvider deps.openssl).out}/" && printf linked
        '';
        expected = "linked";
        extraInputs = [ ];
      };
    }

    // lib.optionalAttrs ((deps ? openssl) && php.tvp.features.digestApi) {
      openssl-core = {
        script = ''
          php -r '$v = explode(" ", OPENSSL_VERSION_TEXT); echo $v[1], " ", substr(openssl_digest("tvp", "sha256"), 0, 16);'
        '';
        expected = "${package.specification.openssl.version} ${tvpDigest}";
      };
    }

    // lib.optionalAttrs ((deps ? openssl) && php.tvp.features.shortArraySyntax) {
      openssl = {
        script = ''
          php -r 'echo explode(" ", OPENSSL_VERSION_TEXT)[1], " ", substr(openssl_digest("tvp", "sha256"), 0, 16);'
        '';
        expected = "${package.specification.openssl.version} ${tvpDigest}";
      };
    }

    // lib.optionalAttrs (deps ? zlib) {
      zlib-linkage = linkage deps.zlib "libz\\.so";
      zlib = {
        script = ''
          php -r 'echo gzuncompress(gzcompress("tvp preserved"));'
        '';
        expected = "tvp preserved";
      };
    }

    // lib.optionalAttrs (deps ? sqlite) {
      # PDO must use the declared external SQLite3 library, even on releases
      # whose direct sqlite_* API still uses upstream's bundled SQLite2.
      sqlite-pdo = {
        script = ''
          php -r '$db = new PDO("sqlite::memory:"); echo $db->query("select 42")->fetchColumn();'
        '';
        expected = "42";
      };

      sqlite-linkage = {
        script = ''
          LD_TRACE_LOADED_OBJECTS=1 "${php}/bin/php" | awk '/libsqlite3\.so/ { print $3 }' | grep -q "^${(runtimeProvider deps.sqlite).out}/" && printf linked
        '';
        expected = "linked";
        extraInputs = [ ];
      };
    }

    // lib.optionalAttrs ((deps ? sqlite) && php.tvp.features.sqlite3Api) {
      sqlite = {
        script = ''
          php ${./fixtures/sqlite.php}
        '';
        expected = "tvp preserved";
      };
    }
    // lib.optionalAttrs php.tvp.features.sqlite2Api {
      sqlite2 = {
        script = ''
          php -r '$db = sqlite_open(":memory:"); $q = sqlite_query($db, "select 42"); echo sqlite_fetch_single($q);'
        '';
        expected = "42";
      };
    }

    // lib.optionalAttrs (deps ? readline) {
      readline-linkage = linkage deps.readline "libreadline\\.so";
      readline = {
        script = ''
          php -r 'echo extension_loaded("readline") ? "loaded" : "absent";'
        '';
        expected = "loaded";
      };
    }
    // lib.optionalAttrs (deps ? libxml2) {
      xml-linkage = linkage deps.libxml2 "libxml2\\.so";
    }
    // lib.optionalAttrs (deps ? libxcrypt) {
      crypt-linkage = linkage deps.libxcrypt "libcrypt\\.so";
    }
    // lib.optionalAttrs (deps ? ncurses) {
      ncurses-linkage = linkage deps.ncurses "lib(tinfow?|ncursesw?)\\.so";
    };
}

// lib.optionalAttrs (package.specification.validationProfile == "selected-phpt4") (
  import ./native-controls.nix { inherit package lib context; }
)
//
  lib.optionalAttrs
    (package.specification.validationProfile == "selected-phpt4" && package.specification.doCheck)
    {
      upstream = import ./selected-phpt.nix { inherit package lib context; };
    }
