# Preserve the former Perl availability only in U, never in A/F.
{
  package,
  lib,
  context,
}:
let
  checked = package.edit (
    s:
    let
      production = s.base.environment s.environment;
      environment = s.base.environment (
        s.environment
        // {
          tools = s.environment.tools ++ [ package.tvp.declaredTestDependencies.perl ];
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
