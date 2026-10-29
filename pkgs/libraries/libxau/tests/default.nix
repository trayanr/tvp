{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests.consumer = {
    script = ''cc -I${package}/include -I${package.tvp.deps.xorgproto}/include ${./fixtures/consumer.c} -L${package}/lib -lXau -ldl -o consumer; ./consumer ${package}/lib/libXau.so'';
    expected = "loaded";
    extraInputs = [ package.tvp.cc ];
  };
}
