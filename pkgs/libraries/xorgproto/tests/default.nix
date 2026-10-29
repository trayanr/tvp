{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests.consumer = {
    script = ''cc -I${package}/include ${./fixtures/consumer.c} -o consumer; ./consumer'';
    expected = "11.0";
    extraInputs = [ package.tvp.cc ];
  };
}
