# Execute the real unpack fragment with changed archive bytes. This isolates the
# source seam without rebuilding an entire compiler/library consumer graph.
{
  package,
  lib,
  context,
}:
let
  deps = package.specification.base.standardTools;
  compression = "xz";
  spec = package.specification;
  codec = if compression == "xz" then deps.xz else deps.gzip;
  fixture = (import ../builder.nix { inherit lib; }) {
    recipe =
      {
        src,
        tar,
        codec,
      }:
      final: {
        pname = "${package.pname}-source-edit-fixture";
        version = package.version;
        inherit src;
        inherit (spec) base bash coreutils;
        plan = [
          (
            (spec.base.environment {
              tools = [
                tar
                codec
              ];
            })
            // {
              name = "fixture.archive";
              run = ''
                mkdir source "$out"
                ${tar}/bin/tar -x${
                  if compression == "xz" then "J" else "z"
                }f ${final.src} --strip-components=1 -C source
                chmod -R u+w source
                printf '%s\n' edited-source > source/.tvp-source-marker
                ${tar}/bin/tar -c${if compression == "xz" then "J" else "z"}f "$out/archive" -C source .
              '';
            }
          )
        ];
      };
    args = {
      src = package.src;
      tar = deps.gnutar;
      inherit codec;
    };
    dependencyNames = [
      "tar"
      "codec"
    ];
    metadata.kind = "owned-test-support";
    selection.kind = "owned-test-support";
    mkTests = _: { };
  };
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
