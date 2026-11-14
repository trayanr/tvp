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
      script = ''
        ${package}/bin/patch --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
      '';
      expected = package.version;
    };
    operation = {
      script = ''
        printf 'before\n' > sample
        printf '%s\n' '--- sample' '+++ sample' '@@ -1 +1 @@' '-before' '+after' > changes
        ${package}/bin/patch -s -p0 < changes
        cat sample
      '';
      expected = "after";
    };
  };
}

// import ./native-owned.nix { inherit pkgs tvpLib package; }
