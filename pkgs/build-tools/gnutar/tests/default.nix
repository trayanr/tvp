{
  pkgs,
  tvpLib,
  package,
  helpers,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
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
// builtins.mapAttrs (
  name: test:
  test.overrideAttrs (old: {
    passthru = (old.passthru or { }) // {
      inherit package;
      testName = name;
    };
  })
) (import ./extended.nix { inherit pkgs package helpers; })
