{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''which --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' '';
      expected = package.version;
    };
    lookup = {
      script = ''
        mkdir -p first second
        touch first/tvp-tool second/tvp-tool
        chmod +x first/tvp-tool second/tvp-tool
        PATH="$PWD/first:$PWD/second" ${package}/bin/which --all tvp-tool | sed "s|$PWD/||"
        if PATH="$PWD/first" ${package}/bin/which nonexistent-command > /dev/null 2>&1; then exit 1; fi
      '';
      expected = "first/tvp-tool\nsecond/tvp-tool";
    };
  };
}
