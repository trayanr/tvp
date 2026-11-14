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
    filenames = {
      script = ''
        mkdir nested
        printf 'before\n' > 'nested/name with spaces'
        printf '%s\n' $'--- a/name with spaces\t2020-01-01 00:00:00 +0000' $'+++ b/name with spaces\t2020-01-01 00:00:00 +0000' '@@ -1 +1 @@' '-before' '+after' > changes
        ${package}/bin/patch -s --directory=nested -p1 < changes
        test "$(cat 'nested/name with spaces')" = after
        ${package}/bin/patch -s --directory=nested -p1 -R < changes
        cat 'nested/name with spaces'
      '';
      expected = "before";
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

// {
  split = import ./ordinary-split.nix { inherit package; };
}
