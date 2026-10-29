{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests.hpack = {
    script = ''cc -I${package}/include ${./fixtures/hpack.c} -L${package}/lib -lnghttp2 -o hpack; ./hpack'';
    expected = package.version;
    extraInputs = [ package.tvp.cc ];
  };
}
