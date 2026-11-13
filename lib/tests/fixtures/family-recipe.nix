# Pure family model: these commands are evaluated but never built.
{
  lib,
  tvp,
  base,
  src,
  version,
  bash,
  coreutils,
  binutils,
  dependency,
  message ? "first",
}:
final: {
  pname = "family-model";
  inherit
    base
    src
    version
    bash
    coreutils
    binutils
    dependency
    ;
  runtime.message = message;
  plan = [
    {
      name = "model.install";
      tools = [ final.dependency ];
      run = ''mkdir -p "$out"; printf compiled > "$out/program"'';
    }
    (tvp.builder.steps.split "model.finalize")
    (tvp.builder.outputs.copyArtifacts { coreutils = final.coreutils; })
    {
      name = "model.finish";
      run = ''printf '%s' ${lib.escapeShellArg final.runtime.message} > "$out/message"'';
    }
  ];
}
