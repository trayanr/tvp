{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''
        ${package}/bin/find --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
      '';
      expected = package.version;
    };
    operation = {
      script = ''
        mkdir tree; touch tree/a.keep tree/b.skip
        ${package}/bin/find tree -type f -name '*.keep' -print0 | ${package}/bin/xargs -0 -n1 basename
      '';
      expected = "a.keep";
    };
    locate = {
      script = ''
        mkdir tree
        touch tree/preserved-marker
        ${package}/bin/updatedb --localpaths="$PWD/tree" --prunepaths="" --netpaths="" --output=locate.db
        ${package}/bin/locate -d locate.db preserved-marker | sed "s|^$PWD/||"
      '';
      expected = "tree/preserved-marker";
    };
  };
}
