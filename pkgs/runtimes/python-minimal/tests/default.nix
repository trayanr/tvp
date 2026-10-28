{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''python3 -c 'import platform; print(platform.python_version())' '';
      expected = package.version;
    };
    stdlib = {
      script = ''python3 ${./fixtures/stdlib.py}'';
      expected = "42";
    };
    profile = {
      script = ''
        python3 -c 'import importlib.util, sys; assert all(importlib.util.find_spec(m) is None for m in sys.argv[1:]); print("minimal")' ${pkgs.lib.escapeShellArgs package.tvp.disabledModules}
      '';
      expected = "minimal";
    };
    embed = {
      script = ''
        cc ${./fixtures/embed.c} $(python3-config --cflags --embed --ldflags) -o embed
        ./embed
      '';
      expected = "42";
      extraInputs = [ package.tvp.cc ];
    };
  };
}
