# One suite, shared by every php version. Never fork it per builder: a test
# that exists only for newer versions cannot detect drift in an older one.
# Guards select whole tests; they never edit a test body.
{
  pkgs,
  tvpLib,
  php,
}:
let
  deps = php.passthru.tvp.deps or { };

  # sha256("tvp"), first 16 hex characters.
  tvpDigest = "f6f6ead0bd85c312";
in
tvpLib.tests.mkSuite {
  inherit pkgs;
  package = php;

  tests =
    {
      version = {
        script = ''
          php -r 'echo PHP_VERSION;'
        '';
        expected = php.version;
      };

      script = {
        script = ''
          cp ${./fixtures/script.php} script.php
          php script.php
        '';
        expected = "tvp nix preserves";
      };

      # ext/dom and ext/simplexml are built by default and silently absent when
      # libxml2 is not found, so a green build alone does not prove them.
      xml = {
        script = ''
          php -r '$d = new DOMDocument(); $d->loadXML("<a><b>tvp</b></a>"); echo $d->getElementsByTagName("b")->item(0)->textContent;'
        '';
        expected = "tvp";
      };

      # phpize, php-config and the installed headers are a separate install
      # path from the interpreter, so nothing above notices when it is
      # incomplete.
      compile = {
        script = ''
          mkdir -p ext && cd ext
          cp ${./fixtures/ext-config.m4} config.m4
          cp ${./fixtures/ext-tvp.c} tvp.c
          phpize > /dev/null
          ./configure --with-php-config="$(command -v php-config)" > /dev/null
          make > /dev/null
          php -d extension="$PWD/modules/tvp.so" -r 'echo tvp_answer();'
        '';
        expected = "42";
        extraInputs = [
          pkgs.stdenv.cc
          pkgs.autoconf
          pkgs.automake
          pkgs.libtool
          pkgs.gnumake
        ];
      };
    }

    // pkgs.lib.optionalAttrs (deps ? openssl) {
      # Reports the OpenSSL that is actually linked, not the one declared, and
      # runs a digest through it so a constant alone cannot pass the test.
      openssl = {
        script = ''
          php -r 'echo explode(" ", OPENSSL_VERSION_TEXT)[1], " ", substr(openssl_digest("tvp", "sha256"), 0, 16);'
        '';
        expected = "${deps.openssl.version} ${tvpDigest}";
      };

      openssl-linkage = {
        script = ''
          ldd "$(command -v php)" | awk '/libssl\.so/ { print $3 }' | grep -q "^${deps.openssl.out}/" && printf linked
        '';
        expected = "linked";
        extraInputs = [ pkgs.glibc.bin ];
      };
    }

    // pkgs.lib.optionalAttrs (deps ? zlib) {
      zlib = {
        script = ''
          php -r 'echo gzuncompress(gzcompress("tvp preserved"));'
        '';
        expected = "tvp preserved";
      };
    }

    // pkgs.lib.optionalAttrs (deps ? sqlite) {
      # ext/sqlite3 and ext/pdo_sqlite are built by default and both vanish
      # quietly when the library is not found.
      sqlite = {
        script = ''
          php ${./fixtures/sqlite.php}
        '';
        expected = "tvp preserved";
      };
    }

    // pkgs.lib.optionalAttrs (deps ? readline) {
      readline = {
        script = ''
          php -r 'echo extension_loaded("readline") ? "loaded" : "absent";'
        '';
        expected = "loaded";
      };
    };
}
