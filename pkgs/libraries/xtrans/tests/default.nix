{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests.consumer = {
    script = ''export PKG_CONFIG_PATH=${package}/share/pkgconfig; test -s ${package}/include/X11/Xtrans/Xtrans.h; pkg-config --modversion xtrans'';
    expected = "1.6.0";
    extraInputs = [ package.tvp.deps.pkg-config ];
  };
}
