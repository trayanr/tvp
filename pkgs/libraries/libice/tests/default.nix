{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests.consumer = {
    script = ''cc -I${package}/include -I${package.tvp.deps.xorgproto}/include -I${package.tvp.deps.xtrans}/include ${./fixtures/consumer.c} -L${package}/lib -lICE -ldl -o consumer; ./consumer ${package}/lib/libICE.so'';
    expected = "loaded";
    extraInputs = [ package.tvp.cc ];
  };
}
