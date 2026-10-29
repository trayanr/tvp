{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests.consumer = {
    script = ''cc -I${package}/include ${./fixtures/consumer.c} -L${package}/lib -ldns_sd -o consumer; ./consumer'';
    expected = "TVP\\032Printer._ipp._tcp.local.";
    extraInputs = [ package.tvp.cc ];
  };
}
