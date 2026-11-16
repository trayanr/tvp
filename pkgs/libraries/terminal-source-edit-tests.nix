{
  package,
  lib,
  context,
  compression ? "gzip",
}:
let
  s = package.specification;
  tools = s.base.tools;
  coreutils = s.base.coreutils;
  bash = s.base.shell;
  binutils = s.base.compiler.bintools;
  codec = if compression == "gzip" then tools.gzip else tools.xz;
  mkSupport =
    name: run:
    (context.mkTest {
      inherit package name;
      script = ":";
      expected = "";
    }).edit
      (
        test:
        test
        // {
          plan = [
            (
              (s.base.environment {
                tools = [
                  coreutils
                  tools.gnutar
                  codec
                ];
              })
              // {
                name = "fixture.${name}";
                inherit run;
              }
            )
          ];
        }
      );
  archive = mkSupport "source-archive" ''
    mkdir source "$out"
    ${tools.gnutar}/bin/tar -x${
      if compression == "gzip" then "z" else "J"
    }f ${package.src} --strip-components=1 -C source
    chmod -R u+w source
    printf '%s\n' edited-source > source/.tvp-source-marker
    ${tools.gnutar}/bin/tar -c${if compression == "gzip" then "z" else "J"}f "$out/archive" -C source .
  '';
  source =
    (package.edit (spec: (removeAttrs spec [ "artifactName" ]) // { src = "${archive}/archive"; }))
    .editSteps
      (plan: [
        (builtins.head plan)
        {
          name = "source.marker-proof";
          run = ''test "$(cat source/.tvp-source-marker)" = edited-source; cp source/.tvp-source-marker "$out"'';
        }
      ]);
in
context.mkSuite {
  inherit package;
  tests.source-edit = {
    tools = [ source ];
    script = "cat ${source}";
    expected = "edited-source";
  };
}
