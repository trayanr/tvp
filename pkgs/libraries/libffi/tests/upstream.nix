{
  package,
  lib,
  context,
}:
let
  s = package.specification;
  harness =
    if (s.upstreamCheck.harness or null) == null then
      package.tvp.declaredTestDependencies.dejagnu
    else
      s.upstreamCheck.harness;
  checked = package.edit (
    old:
    let
      env = old.base.environment (old.environment // { tools = old.environment.tools ++ [ harness ]; });
    in
    old
    // {
      upstreamCheck = old.upstreamCheck // {
        inherit harness;
        tools = env.tools;
        env = env.env // old.upstreamCheck.env;
      };
    }
  );
in
context.mkUpstream { package = checked; }
