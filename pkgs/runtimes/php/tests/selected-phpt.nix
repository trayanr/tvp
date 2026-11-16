# Exact existing four-PHPT scope; no extraction, runner or check feeds A/F.
{
  package,
  lib,
  context,
}:
let
  tools = package.specification.base.tools;
  spec = {
    tools = package.specification.environment.tools ++ [
      tools.gnutar
      tools.gzip
      tools.python
    ];
    script = ''
      mkdir extracted tests
      ${tools.gnutar}/bin/tar -xzf ${package.src} -C extracted --strip-components=1 \
        php-${package.version}/run-tests.php \
        php-${package.version}/ext/standard/tests/strings/str_rot13_basic.phpt \
        php-${package.version}/ext/standard/tests/strings/strrev.phpt \
        php-${package.version}/ext/standard/tests/array/array_sum.phpt \
        php-${package.version}/ext/standard/tests/array/array_product_variation1.phpt
      cp extracted/run-tests.php run-tests.php
      cp extracted/ext/standard/tests/strings/*.phpt extracted/ext/standard/tests/array/*.phpt tests/
      chmod -R u+w tests
      export TEST_PHP_EXECUTABLE=${package}/bin/php TEST_PHP_CGI_EXECUTABLE=${package}/bin/php-cgi
      export NO_INTERACTION=1 REPORT_EXIT_STATUS=1
      status=0
      php run-tests.php -q -n -g PASS,FAIL,SKIP,XFAIL tests > results 2>&1 || status=$?
      cat results >&2
      test "$status" = 0
      ${tools.python}/bin/python3 - <<'CHECK'
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
in
(context.mkTest (
  spec
  // {
    inherit package;
    name = "upstream";
  }
)).edit
  (
    test:
    test
    // {
      validation = {
        role = "upstream-acceptance";
        production = package.artifact;
        installed = package;
        factory = "owned.mkTest";
        scope = "existing four PHPTs only; not full upstream";
      };
    }
  )
