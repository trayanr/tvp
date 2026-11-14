{
  pkgs,
  tvpLib,
  package,
}:
let
  consumer = pkgs.stdenv.mkDerivation {
    name = "ninja-consumer";
    src = pkgs.lib.fileset.toSource {
      root = ./fixtures;
      fileset = ./fixtures/build.ninja;
    };
    nativeBuildInputs = [ package ];
    dontConfigure = true;
    doCheck = true;
    preBuild = ''substituteInPlace build.ninja --replace-fail '@out@' "$out"'';
  };
in
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = "ninja --version";
      expected = package.version;
    };
    shell = {
      script = ''
        cp ${./fixtures/shell.ninja} build.ninja
        PATH=${package}/bin ninja >&2
        cat answer
      '';
      expected = "42";
    };
    dependencies = {
      script = ''
        cp ${./fixtures/main.cc} main.cc
        cp ${./fixtures/dependencies.ninja} build.ninja
        printf '#define ANSWER 41\n' > answer.h
        ninja >&2
        test "$(./main)" = 41
        printf '#define ANSWER 42\n' > answer.h
        ninja >&2
        test "$(./main)" = 42
        ninja | grep -F 'no work to do' >&2
        ./main
      '';
      expected = "42";
      extraInputs = [ package.tvp.cc ];
    };
    phases = {
      script = ''cat ${consumer}/answer'';
      expected = "42";
    };
  };
}
