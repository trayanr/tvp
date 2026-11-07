{ package }:
let
  deps = package.tvp.deps;
in
package.testContext.mkSuite {
  inherit package;
  tools = package.specification.environment.tools ++ [
    deps.python
    deps.binutils
    deps.patchelf
  ];
  libraries = [ package ];
  tests = {
    xs-build-load = {
      script = ''
        make="$(perl -MConfig -e 'print $Config{make}')"
        test "$(command -v "$make")" = '${deps.gnumake}/bin/make'
        cat > Makefile.PL <<'PL'
        use ExtUtils::MakeMaker;
        WriteMakefile(NAME => 'TVP', VERSION => '0.01');
        PL
        cat > TVP.pm <<'PL'
        package TVP;
        use strict; use warnings;
        our $VERSION = '0.01';
        require XSLoader; XSLoader::load('TVP', $VERSION);
        1;
        PL
        cat > TVP.xs <<'XS'
        #include "EXTERN.h"
        #include "perl.h"
        #include "XSUB.h"
        MODULE = TVP PACKAGE = TVP
        int
        answer()
          CODE:
            RETVAL = 42;
          OUTPUT:
            RETVAL
        XS
        perl Makefile.PL > configure.log
        "$make" > build.log
        perl -Mblib -MTVP -e 'die unless TVP::answer() == 42; print "xs-ok"'
      '';
      expected = "xs-ok";
    };
  };
}
