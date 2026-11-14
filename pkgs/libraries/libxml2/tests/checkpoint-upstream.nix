# Existing raw checkpoint factory; strict historical reader remains unchanged.
{
  package,
  lib,
  context,
}:
let
  s = package.specification;
  shared = context.mkUpstream { inherit package; };
  raw = shared.specification.validation.execution;
  header = "include/libxml2/libxml/xmlversion.h";
  binding = builtins.toJSON {
    schema = 1;
    inherit (s) version;
    source = "${s.src}";
    sourceCwd = "/build/workspace/source";
    system = "x86_64-linux";
    features = s.tvp.features;
    runtime = {
      shell = "${s.runtime.shell}";
      libraries = map (p: "${p}") s.runtime.libraries;
    };
    make = "${s.base.standardTools.gnumake}";
    bash = "${s.base.shell}";
    python = "${s.base.standardTools.python}";
    commandCaptureHelper = "${../ordinary/capture-command.py}";
  };
  accepted =
    (context.mkTest {
      inherit package;
      name = "upstream";
      tools = [
        s.base.standardTools.python
        s.base.standardTools.diffutils
      ];
      script = ''
        # The classifier's canonical evidence-root/header relationship is kept.
        # Additionally bind that header to the actual immutable production A.
        test -f ${package.artifact}/${header}
        test "$(readlink -f ${package.artifact}/${header})" = ${package.artifact}/${header}
        cmp -- ${package.artifact}/${header} ${raw}/${header}
        ${s.base.standardTools.python}/bin/python3 -B ${../ordinary/classify.py} \
          ${raw}/nix-support/upstream-raw ${lib.escapeShellArg s.version} \
          --contracts ${../ordinary/source-contracts.json} \
          --binding-json ${lib.escapeShellArg binding} \
          --artifact ${raw} >&2
        printf upstream-passed
      '';
      expected = "upstream-passed";
    }).edit
      (
        test:
        test
        // {
          validation = {
            role = "upstream-acceptance";
            execution = raw;
            production = package.artifact;
            evidenceEnvelope = raw;
            configuredHeaderSource = package.artifact;
            factory = "owned.mkTest";
            policy = "unchanged source-bound strict classifier; all nonpasses/gaps unwaived";
          };
          passthru = test.passthru // {
            upstreamExecution = raw;
          };
        }
      );
in
if s.upstreamProfile == "native-known-corpus-audit" then shared else accepted
