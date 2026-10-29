{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests.consumer = {
    script = ''cc -I${package}/include -I${package.tvp.deps.libxau}/include -I${package.tvp.deps.libxdmcp}/include -I${package.tvp.deps.xorgproto}/include ${./fixtures/consumer.c} -L${package}/lib -lxcb -ldl -o consumer; ./consumer ${package}/lib/libxcb.so'';
    expected = "loaded";
    extraInputs = [ package.tvp.cc ];
  };
}
