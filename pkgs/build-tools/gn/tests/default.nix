{
  pkgs,
  tvpLib,
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
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''gn --version'';
      expected = package.tvp.revision;
    };
    project = {
      script = ''
        cp -r ${source}/. .
        chmod -R u+w .
        substituteInPlace BUILD.gn --replace-fail '@CC@' '${package.tvp.cc}/bin/cc'
        gn gen out > generate.log
        ninja -C out hello > compile.log
        out/hello
      '';
      expected = "42";
      extraInputs = [
        package.tvp.cc
        package.tvp.deps.ninja
      ];
    };
  };
}
