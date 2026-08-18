# One suite, shared by every m4 version. Never fork it per builder: a test that
# exists only for newer versions cannot detect drift in an older one.
# Guards select whole tests; they never edit a test body.
{
  pkgs,
  tvpLib,
  m4,
}:
tvpLib.tests.mkSuite {
  inherit pkgs;
  package = m4;

  tests = {
    version = {
      script = ''
        m4 --version | head -1 | awk '{ print $NF }'
      '';
      expected = m4.version;
    };

    define = {
      script = ''
        printf "define(\`greet', \`tvp')greet\n" | m4
      '';
      expected = "tvp";
    };

    # The arithmetic evaluator, which is a separate engine from macro expansion.
    eval = {
      script = ''
        printf "eval(6 * 7)\n" | m4
      '';
      expected = "42";
    };

    # File inclusion is what autoconf actually leans on.
    include = {
      script = ''
        cp ${./fixtures/included.m4} included.m4
        printf "include(\`included.m4')tvp_included\n" | m4
      '';
      expected = "yes";
    };

    # Quoting is m4's most-used and most-misunderstood feature; a build that got
    # it wrong would corrupt every configure script it touched.
    changequote = {
      script = ''
        printf "changequote([, ])define([q], [tvp])q\n" | m4
      '';
      expected = "tvp";
    };
  };
}
