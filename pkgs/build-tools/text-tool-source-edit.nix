{
  package,
  lib,
  context,
  compression ? "xz",
}:

let
  deps = package.specification.base.standardTools;
  spec = package.specification;
  codec = if compression == "xz" then deps.xz else deps.gzip;
  fixture =
    (context.mkTest {
      inherit package;
      name = "source-edit-fixture";
      script = ":";
      expected = "";
    }).edit
      (
        old:
        old
        // {
          src = package.src;
          plan = [
            (
              (spec.base.environment {
                tools = [
                  deps.gnutar
                  codec
                ];
              })
              // {
                name = "fixture.archive";
                run = ''
                  mkdir source "$out"
                  ${deps.gnutar}/bin/tar -x${
                    if compression == "xz" then "J" else "z"
                  }f ${package.src} --strip-components=1 -C source
                  chmod -R u+w source
                  printf '%s\n' edited-source > source/.tvp-source-marker
                  ${deps.gnutar}/bin/tar -c${if compression == "xz" then "J" else "z"}f "$out/archive" -C source .
                '';
              }
            )
          ];
        }
      );
  edited =
    (package.edit (s: (removeAttrs s [ "artifactName" ]) // { src = "${fixture}/archive"; })).editSteps
      (plan: [
        (builtins.head plan)
        {
          name = "source.marker-proof";
          run = ''
            test "$(cat source/.tvp-source-marker)" = edited-source
            cp source/.tvp-source-marker "$out"
          '';
        }
      ]);
in
context.mkSuite {
  inherit package;
  tools = [ edited ];
  tests.source-edit = {
    script = "cat ${edited}";
    expected = "edited-source";
  };
}
