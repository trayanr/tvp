# The existing checkpoint factory executes the unchanged full upstream suite.
{
  package,
  lib,
  context,
}:
let
  s = package.specification;
  gawkLocales = package.pname == "gawk" && s.installedInterface.hasNls;
  selected =
    if !gawkLocales then
      package
    else
      package.edit (
        old:
        old
        // {
          upstreamCheck = old.upstreamCheck // {
            tools = old.upstreamCheck.tools ++ [ package.tvp.declaredTestDependencies.localeProvider ];
            run = ''
              export LOCPATH=${package.tvp.declaredTestDependencies.checkLocales} PAGER=cat
                      ${old.upstreamCheck.run}'';
          };
        }
      );
in
lib.optionalAttrs s.upstreamCheck.enabled { upstream = context.mkUpstream { package = selected; }; }
