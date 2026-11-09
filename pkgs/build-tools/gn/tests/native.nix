{
  pkgs,
  tvpLib,
  tvp,
  package,
}:
let
  source = pkgs.lib.fileset.toSource {
    root = ./fixtures;
    fileset = pkgs.lib.fileset.unions [
      ./fixtures/.gn
      ./fixtures/BUILD.gn
      ./fixtures/BUILDCONFIG.gn
      ./fixtures/hello.c
    ];
  };
in
package.testContext.mkSuite {
  inherit package;
  tests = {
    source-safety = {
      script = ''${package.specification.python}/bin/python3 -B ${./test_unpack.py} ${../native/unpack.py} >&2; printf source-safe'';
      expected = "source-safe";
      tools = [ package.specification.python ];
    };
    version = {
      script = ''test -s ${package}/share/licenses/gn/LICENSE; gn --version'';
      expected = package.tvp.revision;
    };
    project = {
      script = ''
        cp -r ${source}/. .
        chmod -R u+w .
        ${package.specification.python}/bin/python3 -c "from pathlib import Path; p=Path('BUILD.gn'); p.write_text(p.read_text().replace('@CC@', '${package.tvp.cc}/bin/cc'))"
        gn gen out > generate.log
        ninja -C out hello > compile.log
        out/hello
      '';
      expected = "42";
      tools = [
        package.tvp.cc
        package.tvp.deps.ninja
        package.specification.python
      ];
    };
  };
}
