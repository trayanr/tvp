# Complete installed tools are test-only inputs to restored upstream execution.
{
  package,
  lib,
  context,
}:
let
  s = package.specification;
  t = package.tvp.declaredTestDependencies;
  modern =
    if package.pname == "automake" then
      (package.tvp.features.configuredApi or false)
    else
      s.installedInterface.knownFrontends or false;
  ac = if package.pname == "autoconf" then package else s.autoconf;
  am =
    if package.pname == "automake" then
      package
    else if t ? automake then
      t.automake
    else
      s.automake;
  lt = if package.pname == "libtool" then package else t.libtool;
  extra = lib.optionals modern [
    ac
    am
    lt
  ];
  checked = package.edit (
    spec:
    let
      check = spec.upstreamCheck;
      production = spec.base.environment spec.environment;
      environment = spec.base.environment {
        tools =
          spec.environment.tools
          ++ lib.subtractLists production.tools check.tools
          ++ extra
          ++ [
            spec.base.standardTools.gnutar
            spec.base.standardTools.gzip
          ];
        libraries = spec.environment.libraries or [ ];
        overrides = spec.environment.overrides or { };
      };
      # Recompose provider contributions once; preserve check-only overrides.
      overrides = lib.filterAttrs (name: value: value != (production.env.${name} or null)) check.env;
    in
    spec
    // {
      upstreamCheck = check // {
        tools = environment.tools;
        env = environment.env // overrides;
      };
    }
  );
in
context.mkUpstream { package = checked; }
