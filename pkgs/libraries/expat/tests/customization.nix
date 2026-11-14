# Pure public API controls. Reported tvp.features are metadata, not test policy.
{ package }:
let
  p = package;
  force = q: builtins.tryEval (builtins.deepSeq q.drvPath true);
  same = q: q.drvPath == p.drvPath && q.artifact.drvPath == p.artifact.drvPath;
  source = p.override { src = builtins.toFile "customization-source" "explicit source control"; };
  step = name: q: builtins.head (builtins.filter (s: s.name == name) q.buildSteps);
  unchecked = p.override { doCheck = false; };
  editedPolicy = p.edit (s: s // { doCheck = false; });
  reenabled = unchecked.edit (s: s // { doCheck = true; });
  shell = p.edit (s: s // { base = s.base.override { shell = s.base.coreutils; }; });
  directPolicy = p.edit (
    s:
    s
    // {
      upstreamCheck = s.upstreamCheck // {
        enabled = false;
      };
    }
  );
  metadataOnly = p.edit (
    s:
    s
    // {
      tvp = s.tvp // {
        features = s.tvp.features // {
          doCheck = false;
        };
      };
    }
  );
  changedCommand = p.edit (
    s:
    s
    // {
      upstreamCheck = s.upstreamCheck // {
        run = s.upstreamCheck.run + "\nprintf check-only >&2\n";
      };
    }
  );
  changedPreparation = p.edit (
    s:
    s
    // {
      upstreamPolicy = s.upstreamPolicy // {
        ctestFlags = s.upstreamPolicy.ctestFlags ++ [ "--verbose" ];
      };
    }
  );
  poisoned = p.edit (
    s:
    s
    // {
      doCheck = false;
      upstreamPolicy = throw "disabled Expat policy was forced";
      upstreamCheck = {
        enabled = false;
        run = throw "disabled Expat command was forced";
      };
    }
  );
  results = {
    noopOverride = same (p.override { });
    noopFunctionOverride = same (p.override (_: { }));
    noopEdit = same (p.edit (s: s));
    noopSteps = same (p.editSteps (s: s));
    noopRuntime = same (p.editRuntime (r: r));
    unknownArgument = !(force (p.override { unknownArgument = true; })).success;
    duplicateStep = !(force (p.editSteps (s: s ++ [ (builtins.head s) ]))).success;
    sourceInvalidates = source.drvPath != p.drvPath && source.artifact.drvPath != p.artifact.drvPath;
    sourceStepRebinds = (step "source.unpack" source).run != (step "source.unpack" p).run;
    effectiveBaseRebindsTests =
      shell.tests.consumer.drvPath != p.tests.consumer.drvPath
      && shell.tests.consumer.specification.base.shell.drvPath == p.specification.base.coreutils.drvPath;
    argumentDisablesPolicy =
      !(unchecked.specification.upstreamCheck.enabled) && !(unchecked.tests ? upstream);
    specificationDisablesPolicy =
      !(editedPolicy.specification.upstreamCheck.enabled) && !(editedPolicy.tests ? upstream);
    specificationReenablesPolicy =
      reenabled.specification.upstreamCheck.enabled && reenabled.tests ? upstream;
    directPolicyDisables =
      !(directPolicy.specification.upstreamCheck.enabled) && !(directPolicy.tests ? upstream);
    metadataDoesNotDrivePolicy =
      metadataOnly.specification.upstreamCheck.enabled && metadataOnly.tests ? upstream;
    testPolicyReusesProduction =
      same unchecked && same editedPolicy && same reenabled && same directPolicy;
    disabledPolicyIsLazy = same poisoned && !(poisoned.tests ? upstream);
    commandIsIndependent =
      same changedCommand && changedCommand.tests.upstream.drvPath != p.tests.upstream.drvPath;
    preparationIsIndependent =
      same changedPreparation && changedPreparation.tests.upstream.drvPath != p.tests.upstream.drvPath;
    disabledFeatureReportsPolicy = !(unchecked.specification.tvp.features.doCheck);
  };
  failed = builtins.filter (name: !results.${name}) (builtins.attrNames results);
in
assert failed == [ ] || throw "Expat customization contracts: ${builtins.toJSON failed}";
"customization"
