{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''gperf --version | awk 'NR==1 {print $3}' '';
      expected = package.version;
    };
    generated = {
      script = ''gperf ${./fixtures/words.gperf} > words.c; cc words.c -o words; ./words; printf generated'';
      expected = "generated";
      extraInputs = [ package.tvp.cc ];
    };
  };
}
