# Real tiny archive roundtrip for the newly supported owned-source codec.
{ tvp }:
let
  base = tvp.baseTiers.seed;
  context = tvp.builder.forBase base;
  inherit (context) tools;
in
tvp.builder {
  recipe = _: final: {
    pname = "bzip2-source-helper";
    version = "test";
    src = null;
    inherit base;
    bash = base.shell;
    coreutils = base.coreutils;
    plan = [
      {
        name = "fixture.archive";
        tools = [
          tools.gnutar
          tools.bzip2
        ];
        run = ''
          mkdir input
          printf codec-selected > input/payload
          ${tools.gnutar}/bin/tar -cjf archive.tar.bz2 input
        '';
      }
      (context.steps.unpack {
        src = "archive.tar.bz2";
        compression = "bzip2";
      })
      {
        name = "fixture.verify";
        run = ''
          test "$(cat source/payload)" = codec-selected
          mkdir "$out"
          printf passed > "$out/result"
        '';
      }
    ];
  };
  args = { };
  dependencyNames = [ ];
  metadata.kind = "owned-test-support";
  selection.kind = "owned-test-support";
  mkTests = _: { };
}
