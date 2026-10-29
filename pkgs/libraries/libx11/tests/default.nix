{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests.consumer = {
    script = ''cc -I${package}/include -I${package.tvp.deps.xorgproto}/include -I${package.tvp.deps.xtrans}/include -I${package.tvp.deps.libxcb}/include -I${package.tvp.deps.libxau}/include -I${package.tvp.deps.libxdmcp}/include ${./fixtures/consumer.c} -L${package}/lib -lX11 -ldl -o consumer; ./consumer ${package}/lib/libX11.so'';
    expected = "loaded";
    extraInputs = [ package.tvp.cc ];
  };
}
