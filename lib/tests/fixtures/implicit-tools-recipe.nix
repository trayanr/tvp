# Pure model: all tools come from the selected base and bound helpers.
{
  tvp,
  base,
  src,
  version,
  dependency,
}:
final:
let
  context = tvp.builder.forBase final.base;
in
{
  pname = "implicit-tools";
  inherit
    base
    src
    version
    dependency
    ;
  inherit (context.tools) bash coreutils;
  upstreamPlan = _: throw "production metadata forced upstream-only inputs";
  plan = [
    {
      name = "model.install";
      tools = [ context.tools.gnumake ];
      run = ''mkdir -p "$out"; printf compiled > "$out/program"'';
    }
    (context.steps.split "model.finalize")
    (context.outputs.copyArtifacts { })
  ];
}
