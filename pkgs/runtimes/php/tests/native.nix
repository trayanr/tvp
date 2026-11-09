# One suite, shared by every php version. Never fork it per builder: a test
# that exists only for newer versions cannot detect drift in an older one.
# Guards select whole tests; they never edit a test body.
{
  pkgs,
  tvpLib,
  package,
}:
let
  php = package;
  deps = php.passthru.tvp.deps or { };

  consumerStandard = php.tvp.features.consumerCStandard or null;
  configureEnv = pkgs.lib.optionalString (
    consumerStandard != null
  ) "CFLAGS=\"\${CFLAGS:--g -O2} -std=${consumerStandard}\" ";

  # sha256("tvp"), first 16 hex characters.
  currentCommand = q: builtins.head (builtins.filter (s: s ? env && s.env ? CC) q.buildSteps);
  altered = package.edit (
    s:
    s
    // {
      meta = s.meta // {
        description = "selected";
      };
    }
  );
  marker = package.editSteps (_: [
    {
      name = "php.marker";
      run = "mkdir $out; printf selected > $out/marker";
    }
  ]);
  runtimeControl = (package.editRuntime (r: r // { libraries = [ deps.zlib ]; })).edit (
    s:
    s
    // {
      plan = [
        (
          (s.base.environment {
            tools = [ ];
            libraries = s.runtime.libraries;
          })
          // {
            name = "php.runtime-provider-control";
            run = ''
              mkdir -p "$out/bin"
              printf '#include <zlib.h>\n#include <stdio.h>\nint main(void) { puts(zlibVersion()); }\n' > control.c
              "$CC" control.c -lz -o "$out/bin/control"
            '';
          }
        )
      ];
    }
  );
  rejects = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  contracts = {
    noop = (package.override { }).drvPath == package.drvPath;
    metadata = altered.meta.description == "selected";
    tests = altered.tests.version.package.outPath == altered.outPath;
    factory =
      ((package.mkTests.override { inherit pkgs; }) altered).version.package.outPath == altered.outPath;
    source =
      (builtins.head (package.override { src = builtins.toFile "php-source-probe" "probe"; }).buildSteps)
      .run != (builtins.head package.buildSteps).run;
    environment =
      (currentCommand (
        package.edit (
          s:
          s
          // {
            environment = s.environment // {
              overrides.values.PHP_CONTRACT = "selected";
            };
          }
        )
      )).env.PHP_CONTRACT == "selected";
    unknown = rejects (package.override { unknownDependency = package; }).drvPath;
    feature = !((package.override { testFeatures.passwordApi = false; }).tvp.features.passwordApi);
    provider = (package.override { openssl = deps.zlib; }).drvPath != package.drvPath;
  };
  tvpDigest = "f6f6ead0bd85c312";
  linkage = dependency: soname: {
    script = ''
      paths=$(LD_TRACE_LOADED_OBJECTS=1 "${package}/bin/php" | awk '/${soname}/ { print $3 }')
      test -n "$paths"
      while IFS= read -r path; do
        case "$path" in
          ${pkgs.lib.escapeShellArg "${pkgs.lib.getLib dependency}/"}*) ;;
          *) echo "Unexpected library path: $path" >&2; exit 1 ;;
        esac
      done <<< "$paths"
      printf linked
    '';
    expected = "linked";

  };
in
package.testContext.mkSuite {
  tools = package.specification.environment.tools ++ [
    deps.binutils
    deps.toolPython
  ];
  libraries = [ package ];
  package = php;

  tests =
    {
      constructor =
        assert builtins.all (x: x) (builtins.attrValues contracts);
        {
          script = ''
            test "$(cat ${marker}/marker)" = selected
            test "$(env -i ${runtimeControl}/bin/control)" = '${deps.zlib.version}'
            printf qualified
          '';
          expected = "qualified";
        };
      upstream = {
        script = ''
          cp ${package}/share/php/run-tests.php run-tests.php
          cp -r ${package}/share/php/upstream-tests tests
          chmod -R u+w tests
          export TEST_PHP_EXECUTABLE=${package}/bin/php TEST_PHP_CGI_EXECUTABLE=${package}/bin/php-cgi
          export NO_INTERACTION=1 REPORT_EXIT_STATUS=1
          status=0
          php run-tests.php -q -n -g PASS,FAIL,SKIP,XFAIL tests > results 2>&1 || status=$?
          cat results >&2
          test "$status" = 0
          ${deps.toolPython}/bin/python3 - <<'CHECK'
          import re
          text = re.sub(r"\x1b\[[0-9;]*m", "", open("results").read())
          outcomes = re.findall(r"(?:^|\n|\r)(PASS|FAIL|SKIP|XFAIL) ", text)
          assert len(outcomes) == 4, repr(text)
          assert outcomes.count("PASS") == 4, outcomes
          assert re.search(r"Number of tests\s*:\s*4", text)
          assert re.search(r"Tests failed\s*:\s*0", text)
          CHECK
          printf upstream-4-pass
        '';
        expected = "upstream-4-pass";
      };
      runtime-elf = {
        script = ''
          readelf -l ${package}/bin/php > program-headers
          grep -F '${package.specification.base.compiler.libc}/lib/ld-linux-x86-64.so.2' program-headers >/dev/null
          readelf -d ${package}/bin/php > dynamic
          readelf -W -l ${package}/bin/php | grep 'GNU_STACK' | grep -vq 'RWE'
          env -i ${package}/bin/php -r 'echo PHP_VERSION;' > version
          test -s version
          printf elf-ok
        '';
        expected = "elf-ok";
      };
      version = {
        script = ''
          php -r 'echo PHP_VERSION;'
        '';
        expected = php.version;
      };

      cgi = {
        script = ''php-cgi -q ${./fixtures/cgi.php} '';
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
        script = ''php ${./fixtures/iconv.php}'';
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

    # phpize, php-config and installed headers have a separate install path.
    // pkgs.lib.optionalAttrs php.tvp.features.functionEntryEnd {
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
        tools = package.specification.environment.tools ++ [
          package.tvp.declaredTestDependencies.autoconf
          package.tvp.declaredTestDependencies.automake
          package.tvp.declaredTestDependencies.libtool
          package.tvp.declaredTestDependencies.gnumake
        ];
      };
    }
    // pkgs.lib.optionalAttrs (!php.tvp.features.functionEntryEnd) {
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
        tools = package.specification.environment.tools ++ [
          package.tvp.declaredTestDependencies.autoconf
          package.tvp.declaredTestDependencies.automake
          package.tvp.declaredTestDependencies.libtool
          package.tvp.declaredTestDependencies.gnumake
        ];
      };
    }

    // pkgs.lib.optionalAttrs php.tvp.features.shortArraySyntax {
      script = {
        script = ''
          cp ${./fixtures/script.php} script.php
          php script.php
        '';
        expected = "tvp nix preserves";
      };
    }

    // pkgs.lib.optionalAttrs php.tvp.features.passwordApi {
      password = {
        script = ''
          php -r '$h = password_hash("tvp", PASSWORD_BCRYPT); echo password_verify("tvp", $h) && !password_verify("wrong", $h) ? "verified" : "failed";'
        '';
        expected = "verified";
      };
    }

    // pkgs.lib.optionalAttrs (deps ? openssl) {
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
          LD_TRACE_LOADED_OBJECTS=1 "${package}/bin/php" | awk '/libssl\.so/ { print $3 }' | grep -q "^${deps.openssl.out}/" && printf linked
        '';
        expected = "linked";

      };
    }

    // pkgs.lib.optionalAttrs ((deps ? openssl) && php.tvp.features.digestApi) {
      openssl-core = {
        script = ''
          php -r '$v = explode(" ", OPENSSL_VERSION_TEXT); echo $v[1], " ", substr(openssl_digest("tvp", "sha256"), 0, 16);'
        '';
        expected = "${deps.openssl.version} ${tvpDigest}";
      };
    }

    // pkgs.lib.optionalAttrs ((deps ? openssl) && php.tvp.features.shortArraySyntax) {
      openssl = {
        script = ''
          php -r 'echo explode(" ", OPENSSL_VERSION_TEXT)[1], " ", substr(openssl_digest("tvp", "sha256"), 0, 16);'
        '';
        expected = "${deps.openssl.version} ${tvpDigest}";
      };
    }

    // pkgs.lib.optionalAttrs (deps ? zlib) {
      zlib-linkage = linkage deps.zlib "libz\\.so";
      zlib = {
        script = ''
          php -r 'echo gzuncompress(gzcompress("tvp preserved"));'
        '';
        expected = "tvp preserved";
      };
    }

    // pkgs.lib.optionalAttrs (deps ? sqlite) {
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
          LD_TRACE_LOADED_OBJECTS=1 "${package}/bin/php" | awk '/libsqlite3\.so/ { print $3 }' | grep -q "^${deps.sqlite.out}/" && printf linked
        '';
        expected = "linked";

      };
    }

    // pkgs.lib.optionalAttrs ((deps ? sqlite) && php.tvp.features.sqlite3Api) {
      sqlite = {
        script = ''
          php ${./fixtures/sqlite.php}
        '';
        expected = "tvp preserved";
      };
    }
    // pkgs.lib.optionalAttrs php.tvp.features.sqlite2Api {
      sqlite2 = {
        script = ''
          php -r '$db = sqlite_open(":memory:"); $q = sqlite_query($db, "select 42"); echo sqlite_fetch_single($q);'
        '';
        expected = "42";
      };
    }

    // pkgs.lib.optionalAttrs (deps ? readline) {
      readline-linkage = linkage deps.readline "libreadline\\.so";
      readline = {
        script = ''
          php -r 'echo extension_loaded("readline") ? "loaded" : "absent";'
        '';
        expected = "loaded";
      };
    }
    // pkgs.lib.optionalAttrs (deps ? libxml2) {
      xml-linkage = linkage deps.libxml2 "libxml2\\.so";
    }
    // pkgs.lib.optionalAttrs (deps ? libxcrypt) {
      crypt-linkage = linkage deps.libxcrypt "libcrypt\\.so";
    }
    // pkgs.lib.optionalAttrs (deps ? ncurses) {
      ncurses-linkage = linkage deps.ncurses "lib(tinfow?|ncursesw?)\\.so";
    };
}
