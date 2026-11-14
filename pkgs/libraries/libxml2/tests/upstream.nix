# Strict acceptance of the retained capture is independent of finalization.
# Test failures stay visible without preventing installed-package tests.
{ libxml2, lib }:
let
  s = libxml2.specification;
in
libxml2.testContext.mkTest {
  package = libxml2;
  name = "upstream";
  tools = [ s.tools.python ];
  script = ''
    ${s.tools.python}/bin/python3 -B ${s.classifier} \
      ${libxml2.artifact}/nix-support/upstream-raw ${lib.escapeShellArg s.version} \
      --contracts ${s.sourceContracts} \
      --binding-json ${lib.escapeShellArg s.classificationBinding} \
      --artifact ${libxml2.artifact} >&2
    printf upstream-passed
  '';
  expected = "upstream-passed";
}
