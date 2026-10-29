{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests.consumer = {
    script = ''cc -I${package}/include -I${package.tvp.deps.xorgproto}/include ${./fixtures/consumer.c} -L${package}/lib -lXdmcp -ldl -o consumer; ./consumer ${package}/lib/libXdmcp.so'';
    expected = "loaded";
    extraInputs = [ package.tvp.cc ];
  };
}
