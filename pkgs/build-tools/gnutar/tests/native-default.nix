{
  pkgs,
  tvpLib,
  package,
  helpers,
}:
package.testContext.mkSuite {
  inherit package;
  tools = package.specification.environment.tools;
  tests = {
    remote-helper = {
      script = ''
        ${package}/libexec/rmt --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
      '';
      expected = package.version;
    };
    version = {
      script = ''
        ${package}/bin/tar --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
      '';
      expected = package.version;
    };
    operation = {
      script = ''
        mkdir src dest; printf preserved > src/sample
        ${package}/bin/tar -cf archive.tar -C src sample
        ${package}/bin/tar -xf archive.tar -C dest
        cat dest/sample
      '';
      expected = "preserved";
    };
  };
}
// import ./native-extended.nix {
  inherit
    pkgs
    tvpLib
    package
    helpers
    ;
}

// import ../../../../lib/tests/command-nls.nix {
  inherit package;
  command = "tar";
}
