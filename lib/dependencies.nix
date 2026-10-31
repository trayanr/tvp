# Evaluated declarations, rather than grep matches or builder-specific passthru.
{
  pkgs,
  canonical,
  variants,
  construction,
  compositions ? { },
}:
let
  inherit (pkgs) lib;
  plain = builtins.unsafeDiscardStringContext;
  resolved = dependency: {
    tvp = dependency ? tvp;
    family = dependency.pname or null;
    version = dependency.version or null;
    output = dependency.outputName or "out";
    drv = if (dependency.tvp.status.level or "ok") == "broken" then null else plain dependency.drvPath;
    out = if (dependency.tvp.status.level or "ok") == "broken" then null else plain dependency.outPath;
  };
  rows =
    scope: consumer: package:
    lib.mapAttrsToList (dependency: value: {
      inherit consumer dependency;
      dependencyScope = "recipe";
      consumerVersion = package.version or null;
      definition = package.tvp.definition or null;
      family = package.pname or null;
      scope =
        if (package.tvp.status.level or "ok") == "broken" then
          "broken"
        else
          value.__tvpSelection.category or scope;
      ownerScope = scope;
      selection = value.__tvpSelection or null;
      resolved = resolved value;
      reason =
        package.tvp.dependencyReasons.${dependency} or value.__tvpSelection.reason or (
          if scope == "construction" then
            "Explicit private bootstrap/construction profile dependency."
          else
            null
        );
    }) (package.tvp.declaredDependencies or { });
  namespace =
    scope: entries:
    lib.concatLists (
      lib.mapAttrsToList (
        consumer: package:
        rows scope consumer package
        ++
          map
            (
              edge:
              edge
              // {
                dependencyScope = "test";
                dependency = "test:${edge.dependency}";
              }
            )
            (
              rows scope consumer (
                package
                // {
                  tvp = package.tvp // {
                    declaredDependencies = package.tvp.declaredTestDependencies or { };
                  };
                }
              )
            )
      ) entries
    );
  profiles =
    scope: entries:
    lib.concatLists (
      lib.mapAttrsToList (
        profile: packages:
        namespace scope (
          lib.mapAttrs' (name: package: lib.nameValuePair "${profile}/${name}" package) packages
        )
      ) entries
    );
  supportRows =
    scope: entries:
    lib.concatLists (
      lib.mapAttrsToList (
        consumer: package:
        map (dependency: {
          inherit scope consumer dependency;
          family = package.pname or null;
          definition = package.tvp.definition or null;
          kind = "foreign";
          resolved =
            let
              value = package.tvp.declaredInfrastructure.${dependency} or null;
            in
            if lib.isDerivation value then resolved value else null;
          reason = "Borrowed builder infrastructure, declared separately from recipe.deps.";
        }) (package.tvp.infra or [ ])
      ) entries
    );
in
{
  schema = 1;
  edges =
    namespace "ordinary" canonical
    ++ profiles "public-variant" variants
    ++ profiles "construction" construction.variants
    ++ lib.concatLists (
      lib.mapAttrsToList (
        consumer: package:
        lib.imap0 (i: value: {
          inherit consumer;
          consumerVersion = null;
          definition = consumer;
          family = "android-sdk";
          scope = "composition";
          ownerScope = "composition";
          dependency = "component-${toString i}";
          selection = value.__tvpSelection or null;
          resolved = resolved value;
          reason = "Released SDK artifact/profile selection; preserves the declared SDK composition.";
        }) (package.components or [ ])
      ) compositions
    );
  support =
    supportRows "ordinary" canonical
    ++ lib.concatLists (lib.mapAttrsToList (_: supportRows "public-variant") variants)
    ++ lib.concatLists (lib.mapAttrsToList (_: supportRows "construction") construction.variants);
}
