# One suite, shared by every rustc version. Never fork it per builder: a test
# that exists only for newer versions cannot detect drift in an older one.
# Guards select whole tests; they never edit a test body.
{
  pkgs,
  tvpLib,
  rustc,
}:
let
  # rustc shells out to cc to link, and the sandbox has no compiler unless one
  # is named. A staticlib needs no linker, so that test deliberately omits it.
  cc = [ pkgs.stdenv.cc ];
in
tvpLib.tests.mkSuite {
  inherit pkgs;
  package = rustc;

  tests = {
    version = {
      script = "rustc --version | awk '{ print $2 }'";
      expected = rustc.version;
    };

    compile = {
      script = ''
        rustc ${./fixtures/hello.rs} -o hello
        ./hello
      '';
      expected = "tvp";
      extraInputs = cc;
    };

    edition-2024 = {
      script = ''
        rustc --edition 2024 ${./fixtures/edition2024.rs} -o ed
        ./ed
      '';
      expected = "6";
      extraInputs = cc;
    };

    # A staticlib is what Ruby links YJIT and ZJIT in as, so it needs the
    # standard library rlibs and not just the driver.
    staticlib = {
      script = ''
        rustc --crate-type=staticlib ${./fixtures/hello.rs} -o libtvp.a
        test -s libtvp.a && echo ok
      '';
      expected = "ok";
    };
  };
}
