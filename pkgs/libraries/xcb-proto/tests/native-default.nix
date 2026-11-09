{
  pkgs,
  tvpLib,
  package,
}:
let
  spec = package.specification;
in
package.testContext.mkSuite {
  inherit package;
  libraries = [ package ];
  tools = [ spec.pkgConfig ];
  tests = {
    consumer = {
      tools = [ spec.generatorPython ];
      script = ''
        export PYTHONPATH=${package.development.pythonModuleDirectory}
        ${spec.generatorPython}/bin/python3 -B ${./fixtures/consumer.py} ${package}/share/xcb/xproto.xml
      '';
      expected = "xcbgen-ok";
    };
    layout = {
      tools = [
        spec.generatorPython
        spec.pkgConfig
      ];
      script = ''
        export PYTHONPATH=${package.development.pythonModuleDirectory}
        ${spec.generatorPython}/bin/python3 -B - <<'EOF'
        import sysconfig, xcbgen
        from pathlib import Path
        expected = Path(sysconfig.get_path('purelib', vars={'base': '${package}', 'platbase': '${package}'}))
        assert Path(xcbgen.__file__).parent.parent == expected, (xcbgen.__file__, expected)
        EOF
        test "$(pkg-config --variable=pythondir xcb-proto)" = ${package.development.pythonModuleDirectory}
        test -s ${package}/share/xcb/xinput.xml
        test -s ${package}/share/xcb/xkb.xml
        echo layout-ok
      '';
      expected = "layout-ok";
    };
  };
}
