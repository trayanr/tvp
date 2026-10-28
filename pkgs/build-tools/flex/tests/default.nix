{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''flex --version | awk '{print $NF}' '';
      expected = package.version;
    };
    scanner = {
      script = ''
        PATH=${package}/bin flex ${./fixtures/scanner.l}
        cc lex.yy.c -o scanner
        printf '20 22\n' | ./scanner
      '';
      expected = "42";
      extraInputs = [ package.tvp.cc ];
    };
    cxx = {
      script = ''
        flex --c++ ${./fixtures/scanner.l}
        c++ lex.yy.cc -o scanner
        printf '20 22\n' | ./scanner
      '';
      expected = "42";
      extraInputs = [ package.tvp.cc ];
    };
    bison = {
      script = ''
        bison -d ${./fixtures/calc.y} -o calc.c
        flex -o scanner.c ${./fixtures/calc.l}
        cc calc.c scanner.c -o calc
        printf '20 + 22\n' | ./calc
      '';
      expected = "42";
      extraInputs = [
        package.tvp.cc
        package.tvp.deps.bison
      ];
    };
    libfl = {
      script = ''
        flex ${./fixtures/library.l}
        cc lex.yy.c -lfl -o scanner
        printf '42\n' | ./scanner
      '';
      expected = "42";
      extraInputs = [ package.tvp.cc ];
    };
  };
}
