{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests.consumer = {
    script = ''cc -I${package}/include -I${package.tvp.deps.libx11}/include -I${package.tvp.deps.libxext}/include -I${package.tvp.deps.libxrender}/include -I${package.tvp.deps.xorgproto}/include -I${package.tvp.deps.xtrans}/include -I${package.tvp.deps.libxcb}/include -I${package.tvp.deps.libxau}/include -I${package.tvp.deps.libxdmcp}/include ${./fixtures/consumer.c} -L${package}/lib -lXrandr -ldl -o consumer; ./consumer ${package}/lib/libXrandr.so'';
    expected = "loaded";
    extraInputs = [ package.tvp.cc ];
  };
}
