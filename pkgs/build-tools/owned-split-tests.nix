# Public installed tests keep their factory. The former in-build gate is a
# private check variant, following the reviewed Autotools pattern. Its source,
# fixture construction, execution and acceptance are never production inputs.
{
  pkgs,
  tvp,
  package,
}:
let
  p = package;
  u = p.specification.upstreamCheck or null;
  steps = tvp.builder.steps;
  checked = p.editSteps (
    plan:
    let
      parts = steps.partition plan;
      build = builtins.head (builtins.filter (s: builtins.match ".*\\.build" s.name != null) parts.first);
      prepared = steps.insertBefore build.name (map (s: s // { name = s.name + "-upstream"; }) (
        p.specification.upstreamPreparation or [ ]
      )) plan;
    in
    steps.insertBefore u.before [ (u.command // { enabled = true; }) ] prepared
  );
in
pkgs.lib.optionalAttrs (u != null && u.enabled) {
  upstream = p.testContext.mkTest {
    package = p;
    name = "upstream";
    script = "test -d ${checked}; printf upstream";
    expected = "upstream";
  };
}
