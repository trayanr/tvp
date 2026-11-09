# Ordinary prerequisite contract fixtures follow the selected package's owned
# context. Legacy unpack golden fixtures retain their separate historical route.
{
  tvp,
  package,
  tools,
}:
{
  name,
  buildCommand,
  nativeBuildInputs ? [ ],
}:
tvp.builder {
  recipe =
    {
      base,
      bash,
      coreutils,
      tools,
    }:
    final: {
      pname = name;
      version = "1";
      src = null;
      inherit base bash coreutils;
      plan = [
        (
          (final.base.environment { inherit tools; })
          // {
            name = "fixture.run";
            run = buildCommand;
          }
        )
      ];
    };
  args = {
    base = package.specification.base;
    inherit (package.specification) bash coreutils;
    tools = tools ++ nativeBuildInputs;
  };
  dependencyNames = [
    "bash"
    "coreutils"
    "tools"
  ];
  metadata.kind = "owned-contract-fixture";
  selection.kind = "fixture";
  mkTests = _: { };
}
