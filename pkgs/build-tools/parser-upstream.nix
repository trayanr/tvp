# Test-only tool discovery may enable real cases hidden behind configure conditionals.
{
  package,
  lib,
  context,
}:
let
  t = package.tvp.declaredTestDependencies;
  extra =
    if package.pname == "bison" then
      [
        t.flex
        t.autoconf
      ]
    else
      [ t.bison ];
  checked = package.edit (
    s:
    let
      production = s.base.environment s.environment;
      environment = s.base.environment (
        s.environment
        // {
          tools = s.environment.tools ++ lib.subtractLists production.tools s.upstreamCheck.tools ++ extra;
        }
      );
      overrides = lib.filterAttrs (
        name: value: value != (production.env.${name} or null)
      ) s.upstreamCheck.env;
    in
    s
    // {
      upstreamCheck = s.upstreamCheck // {
        tools = environment.tools;
        env = environment.env // overrides;
      };
    }
  );
in
context.mkUpstream { package = checked; }
