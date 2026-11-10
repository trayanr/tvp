# Pure evaluated-plan policy. No source scanning, realization or baseline mutation.
{ lib }:
let
  steps = import ./build-steps.nix;
  lower = import ./owned-build.nix { inherit lib; };
  plain = builtins.unsafeDiscardStringContext;
  attempt = value: builtins.tryEval (builtins.deepSeq value value);
  nonempty = value: builtins.isString value && builtins.match ".*[^[:space:]].*" value != null;
  identity = p: {
    drv = plain p.drvPath;
    out = plain p.outPath;
  };
  # Compare to a fresh lowering, including Nix dependency contexts: a record
  # containing plausible-looking store strings is not an artifact derivation.
  sameProducer =
    a: b:
    lib.isDerivation a
    && a ? drvPath
    && a ? outPath
    && (a.outputName or null) == (b.outputName or null)
    && identity a == identity b
    && builtins.getContext a.drvPath == builtins.getContext b.drvPath
    && builtins.getContext a.outPath == builtins.getContext b.outPath;
  # Check every selected output, not only the default string coercion. Both
  # output paths and their Nix contexts must name the fresh stage producer.
  sameOutputs =
    a: b:
    a ? outputs
    && a.outputs == b.outputs
    && a ? all
    && builtins.isList a.all
    && builtins.all (
      name:
      builtins.hasAttr name a
      && a.${name} ? outputName
      && a.${name} ? outputs
      && a.${name}.outputName == name
      && a.${name}.outputs == b.outputs
      && sameProducer a.${name} b.${name}
    ) b.outputs
    && builtins.length a.all == builtins.length b.outputs
    && builtins.all (
      i:
      let
        name = builtins.elemAt b.outputs i;
        value = builtins.elemAt a.all i;
      in
      value ? outputName && value.outputName == name && sameProducer value b.${name}
    ) (lib.range 0 (builtins.length b.outputs - 1));
  sameProjectedArtifacts =
    package: artifact:
    builtins.all (
      value:
      value ? artifact && sameProducer value.artifact artifact && sameOutputs value.artifact artifact
    ) (map (name: package.${name}) package.outputs ++ package.all);
  inspectEvaluated =
    namespace: name: p:
    let
      hasPlan = p ? specification && p.specification ? plan && p ? buildSteps;
      owned = p ? stageInputs;
      constructor =
        if owned then
          "owned"
        else if hasPlan then
          "native-plan"
        else
          "legacy";
      planResult = attempt (
        let
          parts = steps.partition p.specification.plan;
        in
        {
          split =
            if builtins.all (s: nonempty s.run) (steps.active (parts.first ++ parts.second)) then
              parts.split
            else
              throw "TVP recipe splits: empty active command";
          activeBefore = builtins.length (steps.active parts.first);
          activeAfter = builtins.length (steps.active parts.second);
          splitCount = builtins.length (
            builtins.filter (s: (s.kind or "command") == "split") p.specification.plan
          );
        }
      );
      producers = attempt (
        let
          expected = lower p.specification;
          exposed = lower (p.specification // { plan = p.buildSteps; });
        in
        sameProducer p expected
        && sameProducer p exposed
        && sameProducer p.artifact expected.artifact
        && sameProducer p.artifact exposed.artifact
        && (
          expected.outputs == [ "out" ]
          || (
            sameOutputs p expected
            && sameOutputs p exposed
            && sameOutputs p.artifact expected.artifact
            && sameOutputs p.artifact exposed.artifact
            && sameProjectedArtifacts p expected.artifact
          )
        )
        && p.artifact.drvPath != p.drvPath
        && p.artifact.outPath != p.outPath
      );
      failure =
        if !hasPlan then
          (if owned then "missing-owned-plan" else "legacy-no-plan")
        else if !planResult.success then
          "invalid-plan"
        else if constructor != "owned" then
          "native-plan-constructor"
        else if !planResult.value.split then
          "owned-unsplit"
        else if !(p ? artifact) then
          "missing-artifact"
        else if !producers.success || !producers.value then
          "invalid-artifact-producer"
        else
          null;
    in
    {
      id = "${namespace}/${name}";
      inherit
        namespace
        name
        constructor
        failure
        ;
      compliant = failure == null;
      status = p.tvp.status or { level = "ok"; };
      outputs = p.outputs or [ "out" ];
      partition = if hasPlan && planResult.success then planResult.value else null;
      producer = identity p;
      artifact = if failure == null then identity p.artifact else null;
      capabilityGap = null;
    };
  inspect =
    namespace: name: p:
    let
      result = attempt (inspectEvaluated namespace name p);
    in
    if result.success then
      result.value
    else
      {
        id = "${namespace}/${name}";
        inherit namespace name;
        constructor = "unavailable";
        failure = "evaluation-failed";
        compliant = false;
        status = {
          level = "unknown";
          reason = "Constructor evaluation failed before metadata could be inspected.";
        };
        outputs = [ ];
        partition = null;
        producer = null;
        artifact = null;
        capabilityGap = "Repair the constructor/plan evaluation error; this row cannot use a migration exception.";
      };
in
{
  inventory =
    {
      canonical,
      variants ? { },
    }:
    {
      schema = "tvp.recipe-splits.inventory/v1";
      scope = "Every canonical release (including declared broken releases) and public named variant; aliases are selectors, never additional rows.";
      rows =
        lib.mapAttrsToList (inspect "canonical") canonical
        ++ lib.concatLists (
          lib.mapAttrsToList (
            profile: entries: lib.mapAttrsToList (inspect "variants.${profile}") entries
          ) variants
        );
    };

  # Nix's JSON parser silently keeps the last duplicate member. Require one
  # canonical, sorted-key JSON record per line so duplicate members cannot hide.
  baselineFromJSON =
    text:
    let
      parsed = builtins.fromJSON text;
      canonical =
        if parsed == [ ] then
          "[]\n"
        else
          "[\n" + lib.concatStringsSep ",\n" (map (e: "  " + builtins.toJSON e) parsed) + "\n]\n";
    in
    if builtins.isList parsed && text == canonical then
      parsed
    else
      throw "TVP recipe splits: baseline must use one canonical sorted-key JSON record per line (no duplicate members).";

  # A list deliberately preserves duplicate IDs for validation. Unknown fields,
  # namespaces, wildcard IDs, null/blank reasons and contradictory classes fail.
  validate =
    {
      inventory,
      baseline ? [ ],
      strict ? false,
    }:
    let
      rows = inventory.rows;
      debts = builtins.filter (r: !r.compliant) rows;
      ids = map (r: r.id) rows;
      classes = {
        legacy = [ "legacy-no-plan" ];
        native-plan = [
          "native-plan-constructor"
          "invalid-plan"
        ];
        owned = [
          "owned-unsplit"
          "missing-owned-plan"
          "invalid-plan"
          "missing-artifact"
          "invalid-artifact-producer"
        ];
      };
      validEntry =
        e:
        builtins.isAttrs e
        &&
          builtins.attrNames e == [
            "constructor"
            "failure"
            "id"
            "reason"
          ]
        && builtins.isString e.id
        && !builtins.hasContext e.id
        && builtins.match "(canonical|variants\\.[a-zA-Z0-9_-]+)/[a-zA-Z0-9_+-]+" e.id != null
        && builtins.isString e.constructor
        && !builtins.hasContext e.constructor
        && builtins.isString e.failure
        && !builtins.hasContext e.failure
        && builtins.hasAttr e.constructor classes
        && builtins.elem e.failure classes.${e.constructor}
        && nonempty e.reason
        && !builtins.hasContext e.reason;
      listOK = builtins.isList baseline;
      entriesOK = listOK && builtins.all validEntry baseline;
      baselineIds = map (e: e.id) baseline;
      shapeOK = entriesOK && builtins.length baselineIds == builtins.length (lib.unique baselineIds);
      matched =
        row:
        builtins.any (
          e: e.id == row.id && e.constructor == row.constructor && e.failure == row.failure
        ) baseline;
      unused =
        if !shapeOK then
          [ ]
        else
          builtins.filter (
            e:
            !(builtins.any (
              r: r.id == e.id && !r.compliant && r.constructor == e.constructor && r.failure == e.failure
            ) rows)
          ) baseline;
      newDebt = if !shapeOK then debts else builtins.filter (r: !matched r) debts;
      errors =
        lib.optional (!shapeOK)
          "Malformed split baseline: expected unique exact IDs, known classifications and nonblank actionable reasons."
        ++ lib.optional (builtins.length ids != builtins.length (lib.unique ids)) "Duplicate inventory IDs."
        ++ map (r: "Unbaselined failure ${r.id}: ${r.constructor}/${r.failure}") newDebt
        ++ map (
          e: "Stale or classification-drift baseline entry ${e.id}: ${e.constructor}/${e.failure}"
        ) unused
        ++ lib.optional (strict && debts != [ ]) "Strict split admission requires zero remaining debt.";
      report = {
        schema = "tvp.recipe-splits.report/v1";
        inherit (inventory) scope rows;
        inherit strict errors;
        success = errors == [ ];
        allSplit = debts == [ ];
        status =
          if errors != [ ] then
            "FAIL"
          else if debts == [ ] then
            "ALL_SPLIT"
          else
            "PASS_WITH_EXISTING_DEBT";
        counts = {
          total = builtins.length rows;
          canonical = builtins.length (builtins.filter (r: r.namespace == "canonical") rows);
          publicVariants = builtins.length (builtins.filter (r: r.namespace != "canonical") rows);
          broken = builtins.length (builtins.filter (r: r.status.level == "broken") rows);
          compliant = builtins.length rows - builtins.length debts;
          existingDebt = if shapeOK then builtins.length (builtins.filter matched debts) else 0;
          unbaselined = builtins.length newDebt;
          remainingDebt = builtins.length debts;
          baselineEntries = if listOK then builtins.length baseline else 0;
          stale = builtins.length unused;
          byFailure = lib.mapAttrs (_: xs: builtins.length xs) (lib.groupBy (r: r.failure) debts);
          byConstructor = lib.mapAttrs (_: xs: builtins.length xs) (lib.groupBy (r: r.constructor) rows);
        };
        remaining = map (
          r:
          r
          // {
            reason =
              if shapeOK && matched r then
                (builtins.head (builtins.filter (e: e.id == r.id) baseline)).reason
              else
                null;
          }
        ) debts;
      };
    in
    assert !(builtins.hasContext (builtins.toJSON report));
    report;

  enforce =
    report:
    if report.success then
      report
    else
      throw "TVP recipe splits: ${lib.concatStringsSep "\n" report.errors}";
}
