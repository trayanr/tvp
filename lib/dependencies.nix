# Evaluated declarations, rather than grep matches or builder-specific passthru.
{
  pkgs,
  canonical,
  variants,
  construction,
  compositions ? { },
  buildTestSupport ? { },
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
  owners =
    scope: entries:
    lib.mapAttrsToList (consumer: package: {
      inherit consumer;
      scope = if (package.tvp.status.level or "ok") == "broken" then "broken" else scope;
      ownerScope = scope;
      family = package.pname or null;
      version = package.version or null;
      definition = package.tvp.definition or null;
      base = package.tvp.base or null;
      status = package.tvp.status or null;
      dependencies = builtins.attrNames (package.tvp.declaredDependencies or { });
      testDependencies = builtins.attrNames (package.tvp.declaredTestDependencies or { });
    }) entries;
  profileOwners =
    scope: entries:
    lib.concatLists (
      lib.mapAttrsToList (
        profile: packages:
        owners scope (
          lib.mapAttrs' (name: package: lib.nameValuePair "${profile}/${name}" package) packages
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
        map (
          dependency:
          let
            value = package.tvp.declaredInfrastructure.${dependency} or null;
            isPackage = lib.isDerivation value;
            isDerivedString = builtins.isString value && builtins.hasContext value;
          in
          {
            inherit scope consumer dependency;
            family = package.pname or null;
            definition = package.tvp.definition or null;
            role =
              if isPackage then
                "derivation"
              else if isDerivedString then
                "derived-string"
              else
                "helper";
            kind =
              if isPackage && !(value ? tvp) then
                "foreign"
              else if isPackage || isDerivedString then
                "unknown"
              else
                null;
            selection = if builtins.isAttrs value then value.__tvpSelection or null else null;
            resolved =
              if isPackage then
                resolved value
              else if isDerivedString then
                {
                  tvp = null;
                  family = null;
                  version = null;
                  drv = null;
                  out = plain value;
                  output = null;
                  context = builtins.getContext value;
                }
              else
                null;
            details =
              if isDerivedString then
                "Generated infrastructure string: producer context is known, requested package selector is not available."
              else if !isPackage then
                "Non-derivation builder helper; not a package dependency selection. Origin is not inferred."
              else
                null;
            reason = "Builder infrastructure, declared separately from recipe.deps.";
          }
        ) (package.tvp.infra or [ ])
      ) entries
    );
  profileSupport =
    scope: entries:
    lib.concatLists (
      lib.mapAttrsToList (
        profile: packages:
        supportRows scope (
          lib.mapAttrs' (name: package: lib.nameValuePair "${profile}/${name}" package) packages
        )
      ) entries
    );

in
{
  schema = 1;
  consumers =
    owners "ordinary" canonical
    ++ profileOwners "public-variant" variants
    ++ profileOwners "construction" construction.variants
    ++ lib.mapAttrsToList (consumer: package: {
      inherit consumer;
      scope = "composition";
      ownerScope = "composition";
      family = "android-sdk";
      version = null;
      definition = consumer;
      base = null;
      status = null;
      dependencies = lib.imap0 (i: _: "component-${toString i}") (package.components or [ ]);
      testDependencies = [ ];
    }) compositions;
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
    lib.concatLists (
      lib.mapAttrsToList (
        consumer: dependencies:
        lib.mapAttrsToList (dependency: value: {
          inherit consumer dependency;
          scope = "build-test-support";
          selection = value.__tvpSelection or null;
          resolved = resolved value;
          reason = "Repository audit test interpreter.";
        }) dependencies
      ) buildTestSupport
    )
    ++ supportRows "ordinary" canonical
    ++ profileSupport "public-variant" variants
    ++ profileSupport "construction" construction.variants;
}
