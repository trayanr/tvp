{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests.consumer = {
    script = ''
      cc -I${package}/include -I${package}/include/freetype2 ${./fixtures/consumer.c} -L${package}/lib -lfreetype -o consumer
      ./consumer ${./fixtures/font.bdf}
    '';
    expected = package.version;
    extraInputs = [ package.tvp.cc ];
  };
}
