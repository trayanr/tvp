{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests.consumer = {
    script = ''PYTHONPATH=${package}/lib/python3.12/site-packages python3 ${./fixtures/consumer.py} ${package}/share/xcb/xproto.xml'';
    expected = "xcbgen-ok";
    extraInputs = [ package.tvp.deps.python ];
  };
}
