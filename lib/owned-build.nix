# Lower only stage-local prepared commands to the Nix primitive.
{ lib }:
spec:
let
  inherit (spec)
    pname
    version
    base
    bash
    coreutils
    plan
    ;
  declaredPassthru = spec.passthru or { };
  validatePassthru =
    names: metadata:
    if names != [ "out" ] && lib.intersectLists names (builtins.attrNames metadata) != [ ] then
      throw "TVP named outputs: output name collides with passthru metadata"
    else
      metadata;
  outputNames =
    let
      names = import ./named-outputs.nix { inherit lib; } (spec.outputs or [ "out" ]);
    in
    # A callback needs the raw outputs; output construction must not depend on it.
    if names == [ "out" ] || builtins.isFunction declaredPassthru then
      names
    else
      builtins.seq (validatePassthru names declaredPassthru) names;
  compiler = if base ? compiler then base.compiler else base.stdenv.cc;
  # Opt-in consumers must not silently discard an unknown recipe exception.
  # The legacy branch is exactly the earlier rendering and compiler protocol.
  hardeningValidation =
    if compiler ? hardeningPolicy then
      builtins.deepSeq (import ./hardening-policy.nix {
        defaults = compiler.defaultHardeningFlags;
        disable = spec.hardeningDisable or [ ];
      }) true
    else
      true;
  baselineTools = if base ? compiler then [ base.shell ] ++ base.tools else base.stdenv.initialPath;
  multiOutput = outputNames != [ "out" ];
  steps = import ./build-steps.nix;
  parts = steps.partition plan;
  splitNamed = multiOutput && parts.split;
  artifactName =
    if !(spec ? artifactName) then
      "${pname}-${version}-artifacts"
    else if !parts.split then
      throw "TVP artifact name: an explicit name requires a split"
    else if
      builtins.isString spec.artifactName
      && !(builtins.hasContext spec.artifactName)
      && builtins.match "[a-zA-Z0-9][a-zA-Z0-9+._?=-]*" spec.artifactName != null
    then
      spec.artifactName
    else
      throw "TVP artifact name: expected a nonempty context-free store basename";
  stage =
    name: commands: artifact:
    let
      selected = steps.active commands;
      runner =
        import ./build-step-runner.nix
          {
            inherit
              lib
              base
              bash
              coreutils
              ;
          }
          {
            plan = map (
              step:
              step
              // {
                tools = lib.unique (step.tools ++ baselineTools);
                run =
                  ''
                    export NIX_HARDENING_ENABLE=${lib.escapeShellArg (lib.concatStringsSep " " compiler.defaultHardeningFlags)}
                    export SOURCE_DATE_EPOCH=315532800
                    if [[ -e "$TVP_SOURCE_ROOT/source-date-epoch" ]]; then
                      SOURCE_DATE_EPOCH=$(cat "$TVP_SOURCE_ROOT/source-date-epoch")
                    fi
                    ${lib.optionalString (artifact != null)
                      ''readonly TVP_ARTIFACT_ROOT=${lib.escapeShellArg (toString artifact)}; export TVP_ARTIFACT_ROOT''
                    }
                  ''
                  + lib.optionalString (splitNamed && artifact != null) (
                    # Explicit contextual bindings in every fresh suffix step.
                    # No output discovery and no final paths in the prefix.
                    "readonly -A TVP_ARTIFACT_OUTPUTS=(\n"
                    + lib.concatMapStringsSep "\n" (
                      output: "[${output}]=${lib.escapeShellArg (toString artifact.${output})}"
                    ) outputNames
                    + "\n)\n"
                  )
                  + step.run;
              }
            ) selected;
            temporaryDirectories = true;
            owned = true;
            outputs = outputNames;
          };
      drv = builtins.derivation (
        {
          inherit name;
          __structuredAttrs = true;
          stageInputs = map toString runner.inputs;
          inherit (base.platform) system;
          builder = "${bash}/bin/bash";
          args = [
            "-euc"
            ''
              source "$NIX_ATTRS_SH_FILE"
              ${
                if multiOutput then
                  lib.concatMapStringsSep "\n" (name: ''export ${name}="''${outputs[${name}]}"'') outputNames
                else
                  ''export out="''${outputs[out]}"''
              }
              export NIX_BUILD_TOP="$PWD"
              ${coreutils}/bin/mkdir workspace
              ${bash}/bin/bash ${runner.script} "$PWD/workspace"${
                lib.optionalString splitNamed (
                  "\n" + lib.concatMapStringsSep "\n" (output: ''test -d "''${outputs[${output}]}"'') outputNames
                )
              }
            ''
          ];
          outputs = outputNames;
        }
        // lib.optionalAttrs (splitNamed && artifact != null) {
          # Retain unrelated caller checks, including those for other outputs.
          outputChecks =
            (spec.outputChecks or { })
            // lib.genAttrs outputNames (
              output:
              let
                declared = (spec.outputChecks or { }).${output} or { };
              in
              declared
              // {
                disallowedReferences =
                  (declared.disallowedReferences or [ ])
                  ++ map (name: artifact.${name}) outputNames;
              }
            );
        }
        // lib.optionalAttrs (artifact != null && !splitNamed) {
          # Native Nix output checks; never introduce a reference merely to test it.
          outputChecks.out.disallowedReferences = [ artifact ];
        }
      );
    in
    drv // { buildStepRunner = runner; };
  artifact = stage artifactName parts.first null;
  package = builtins.seq hardeningValidation (
    builtins.seq artifactName (
      if parts.split then
        stage "${pname}-${version}" parts.second artifact
      else
        stage "${pname}-${version}" parts.first null
    )
  );
  exports = lib.concatMap (s: s.developmentLibraries or [ ]) (
    steps.active (parts.first ++ parts.second)
  );
in
package
// {
  inherit pname version;
  inherit (spec) src;
  meta = spec.meta or { };
  tvp = spec.tvp or { };
  runtime = spec.runtime or { };
  development =
    (
      let
        declared = spec.development or { };
      in
      if builtins.isFunction declared then declared package else declared
    )
    // {
      libraries = lib.unique exports;
    };
  buildEnvironment = spec.buildEnvironment or (_: { });
  # Like development, output-relative public data may depend on the raw output.
  passthru = validatePassthru outputNames (
    if builtins.isFunction declaredPassthru then declaredPassthru package else declaredPassthru
  );
}
// (if base ? compiler then { inherit compiler; } else { stdenv = base.stdenv; })
// lib.optionalAttrs parts.split { artifact = artifact; }
