{ tvp }:
let
  package = name: rec {
    type = "derivation";
    inherit name;
    outputs = [ "out" ];
    outPath = "/nix/store/registry-fixture-${name}";
    out = {
      inherit outPath;
    };
    tvp = {
      builder = "build-1.nix";
      definition = "1";
    };
  };
  library = package "library";
  reference = package "reference";
  customized = library // {
    outputs = [
      "out"
      "dev"
    ];
    outPath = "/nix/store/registry-fixture-customized";
    out.outPath = "/nix/store/registry-fixture-customized";
    dev.outPath = "/nix/store/registry-fixture-customized-dev";
    __tvpSelection = {
      namespace = "packages";
      canonical = "library_1";
      kind = "override";
    };
    tvp = library.tvp // {
      customization.customized = true;
      declaredDependencies.foreign = package "foreign";
    };
    specification.base.referencePackages = [ reference ];
  };
  invalid = {
    borrowed = customized // {
      tvp = { };
    };
    unknownRecipe = customized // {
      __tvpSelection = customized.__tvpSelection // {
        canonical = "absent";
      };
    };
    unknownNamespace = customized // {
      __tvpSelection = customized.__tvpSelection // {
        namespace = "external";
      };
    };
    wrongBuilder = customized // {
      tvp = customized.tvp // {
        builder = "foreign.nix";
      };
    };
    unmodified = customized // {
      __tvpSelection = customized.__tvpSelection // {
        kind = "major";
      };
    };
    broken = customized // {
      tvp = customized.tvp // {
        status.level = "broken";
      };
    };
  };
  registry =
    dependency:
    tvp.lib.provenance.registry {
      canonical = {
        library_1 = library;
        app_1 = (package "app") // {
          tvp.declaredDependencies.library = dependency;
          tvp.declaredTestDependencies.testOnly = customized // {
            out.outPath = "/nix/store/registry-fixture-test-only";
          };
        };
      };
      variants = { };
      bases = { };
    };
  rows = registry customized;
  dependencies = builtins.filter (row: row.kind == "definition-dependency") rows;
  references = builtins.filter (row: row.kind == "definition-reference") rows;
  canonicalOverride = customized // {
    __tvpSelection = customized.__tvpSelection // {
      namespace = "canonical";
    };
  };
in
{
  allOutputs =
    map (row: row.path) dependencies == [
      customized.out.outPath
      customized.dev.outPath
    ];
  declaredOwner = builtins.all (
    row: row.name == "app_1/library" && row.source == "source"
  ) dependencies;
  baseReferences = map (row: row.path) references == [ reference.outPath ];
  canonicalNamespace = registry canonicalOverride == rows;
  rejectsNonRecipeDependencies = builtins.all (
    dependency: !(builtins.any (row: row.kind == "definition-dependency") (registry dependency))
  ) (builtins.attrValues invalid);
  testOnlyNotRegistered =
    !(builtins.any (row: row.path == "/nix/store/registry-fixture-test-only") rows);
  transitiveNotRegistered =
    !(builtins.any (row: row.path == "/nix/store/registry-fixture-foreign") rows);
  contextFree = !(builtins.hasContext (builtins.toJSON rows));
}
