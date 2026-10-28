{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''bison --version | head -1 | awk '{print $NF}' '';
      expected = package.version;
    };
    parser = {
      script = ''
        # A restricted PATH proves Bison can locate its declared M4 itself.
        PATH=${package}/bin bison -d ${./fixtures/calc.y} -o calc.c
        cc calc.c -o calc
        ./calc
      '';
      expected = "42";
      extraInputs = [ package.tvp.cc ];
    };
    cxx = {
      script = ''
        bison ${./fixtures/calc.yy} -o calc.cc
        c++ calc.cc -o calc
        ./calc
      '';
      expected = "42";
      extraInputs = [ package.tvp.cc ];
    };
    yacc = {
      script = ''
        yacc ${./fixtures/calc.y}
        cc y.tab.c -o calc
        ./calc
      '';
      expected = "42";
      extraInputs = [ package.tvp.cc ];
    };
  };
}
