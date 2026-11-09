{
  pkgs,
  tvpLib,
  package,
}:
package.testContext.mkSuite {
  tools = with package.specification; [
    sed
    grep
    gawk
    diffutils
    findutils
  ];
  inherit package;
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

// import ./native-owned.nix { inherit pkgs tvpLib package; }
