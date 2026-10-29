{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests.consumer = {
    script = ''
      cc -I${package}/include  ${./fixtures/consumer.c} -L${package}/lib -lasound -o consumer
      ./consumer
    '';
    expected = package.version;
    extraInputs = [ package.tvp.cc ];
  };
}
