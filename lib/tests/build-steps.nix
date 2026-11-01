# Evaluation only: synthetic derivations below must never be realized.
let
  steps = import ../build-steps.nix;
  names = map (step: step.name);
  rejects = value: !(builtins.tryEval (builtins.seq value true)).success;
  failsNames = value: !(builtins.tryEval (builtins.deepSeq (names value) true)).success;
  boom = throw "disabled payload was evaluated";
  json = steps.namespace "json-c" [
    {
      name = "configure";
      tools = [
        "cmake"
        "make"
      ];
      libraries = [
        "libc"
        "headers"
      ];
      cwd = "source";
      env = {
        CC = "cc";
        CFLAGS = "-O2";
      };
      run = "configure";
      metadata = {
        note = "preserve me";
        deferred = boom;
      };
    }
    {
      name = "build";
      run = "build";
    }
    {
      name = "check";
      enabled = false;
      run = "check";
    }
    {
      name = "install";
      run = "install";
    }
  ];
  assets = steps.namespace "assets" [
    {
      name = "build";
      tools = [
        "packer"
        "compressor"
      ];
      libraries = [ "images" ];
      env = {
        MODE = "small";
      };
      cwd = "assets";
      run = "pack";
    }
  ];
  original = json ++ assets;
  inserted = steps.insertBefore "json-c.install" [
    {
      name = "custom.audit";
      run = "audit";
    }
  ] original;
  replaced = steps.replace "json-c.check" (old: old // { run = "new check"; }) inserted;
  enabled = steps.replace "json-c.check" (old: old // { enabled = true; }) replaced;
  final = steps.append [
    {
      name = "custom.finish";
      run = "finish";
    }
  ] (steps.delete "json-c.build" enabled);
  disabled = [
    {
      name = "lazy.check";
      enabled = false;
      run = boom;
      tools = boom;
      libraries = boom;
      env = boom;
      cwd = boom;
      metadata = boom;
    }
  ];
  afterDisabled = steps.insertAfter "lazy.check" [
    {
      name = "lazy.after";
      run = "after";
    }
  ] disabled;
  synthetic =
    name:
    builtins.derivation {
      inherit name;
      system = "x86_64-linux";
      builder = "/never-realize";
    };
  tool = synthetic "step-active-tool";
  library = synthetic "step-active-library";
  environment = synthetic "step-active-env";
  script = synthetic "step-active-run";
  directory = synthetic "step-active-cwd";
  inactive = synthetic "step-disabled";
  contextPlan = [
    {
      name = "contexts.active";
      tools = [ tool ];
      libraries = [ library ];
      env = {
        DATA = "${environment}";
      };
      run = "${script}/bin/run";
      cwd = "${directory}/source";
    }
    {
      name = "contexts.disabled";
      enabled = false;
      tools = [ inactive ];
      libraries = [ inactive ];
      env = {
        DATA = "${inactive}";
      };
      run = "${inactive}/run";
      cwd = "${inactive}";
    }
  ];
  selected = steps.active contextPlan;
  # A consumer's small active-only projection, not a renderer of the full plan.
  projection = builtins.toJSON (
    map (s: {
      tools = map toString s.tools;
      libraries = map toString s.libraries;
      inherit (s) env run cwd;
    }) selected
  );
  context = builtins.getContext projection;
  expectedContext = builtins.getContext "${tool}${library}${environment}${script}${directory}";
  checks = {
    literalComposition =
      names original == [
        "json-c.configure"
        "json-c.build"
        "json-c.check"
        "json-c.install"
        "assets.build"
      ];
    insertion =
      names inserted == [
        "json-c.configure"
        "json-c.build"
        "json-c.check"
        "custom.audit"
        "json-c.install"
        "assets.build"
      ];
    replacePreservesDisabled =
      !(builtins.elemAt replaced 2).enabled && (builtins.elemAt replaced 2).run == "new check";
    explicitReenable =
      (builtins.elemAt enabled 2).enabled && (builtins.elemAt enabled 2).run == "new check";
    deleteAppendOrder =
      names final == [
        "json-c.configure"
        "json-c.check"
        "custom.audit"
        "json-c.install"
        "assets.build"
        "custom.finish"
      ];
    originalImmutable =
      names original == [
        "json-c.configure"
        "json-c.build"
        "json-c.check"
        "json-c.install"
        "assets.build"
      ]
      && !(builtins.elemAt original 2).enabled;
    unchangedFields =
      let
        s = builtins.head (steps.active inserted);
      in
      s.tools == [
        "cmake"
        "make"
      ]
      &&
        s.libraries == [
          "libc"
          "headers"
        ]
      && s.cwd == "source"
      &&
        s.env == {
          CC = "cc";
          CFLAGS = "-O2";
        }
      && s.metadata.note == "preserve me";
    defaults =
      let
        s = builtins.elemAt (steps.active original) 1;
      in
      s.enabled && s.cwd == "." && s.tools == [ ] && s.libraries == [ ] && s.env == { };
    scopedFields =
      let
        s = builtins.elemAt (steps.active original) 3;
      in
      s.env == {
        MODE = "small";
      }
      && s.cwd == "assets"
      &&
        s.tools == [
          "packer"
          "compressor"
        ];
    disabledPosition =
      names afterDisabled == [
        "lazy.check"
        "lazy.after"
      ]
      && names (steps.active afterDisabled) == [ "lazy.after" ];
    disabledPayloadsLazy =
      names (steps.validate disabled) == [ "lazy.check" ]
      && steps.active disabled == [ ]
      && steps.active (steps.replace "lazy.check" (old: old // { run = boom; }) disabled) == [ ];
    disabledDelete = steps.delete "lazy.check" disabled == [ ];
    disabledReenableLazyEdit =
      names (steps.replace "lazy.check" (old: old // { enabled = true; }) disabled) == [ "lazy.check" ];
    activeContextsPreserved =
      context == expectedContext && builtins.length (builtins.attrNames context) == 5;
    disabledContextsExcluded =
      !(builtins.hasAttr (builtins.unsafeDiscardStringContext inactive.drvPath) context);
    namesContextFree = !(builtins.hasContext (builtins.toJSON (names (steps.validate contextPlan))));
    missingBefore = rejects (steps.insertBefore "missing.target" [ ] original);
    missingAfter = rejects (steps.insertAfter "missing.target" [ ] original);
    missingReplace = rejects (steps.replace "missing.target" (old: old) original);
    missingDelete = rejects (steps.delete "missing.target" original);
    deleteThenReplace = rejects (
      steps.replace "json-c.check" (old: old) (steps.delete "json-c.check" original)
    );
    invalidTarget = rejects (steps.delete "configure" original);
    duplicateSuffix = rejects (
      steps.validate (
        original
        ++ [
          {
            name = "json-c.configure";
            run = boom;
          }
        ]
      )
    );
    disabledDuplicate = rejects (steps.validate (disabled ++ disabled));
    prefixCollision = rejects (
      steps.validate (
        json
        ++ steps.namespace "json-c" [
          {
            name = "check";
            enabled = false;
            run = boom;
          }
        ]
      )
    );
    invalidSuffix = rejects (steps.validate (original ++ [ { name = "bad name"; } ]));
    missingName = rejects (steps.validate [ { enabled = false; } ]);
    invalidRecord = rejects (steps.validate [ 42 ]);
    invalidList = rejects (steps.validate { });
    invalidBooleanSuffix = rejects (
      steps.validate (
        original
        ++ [
          {
            name = "bad.boolean";
            enabled = "false";
          }
        ]
      )
    );
    contextfulName = rejects (steps.validate [ { name = "${inactive}.check"; } ]);
    invalidNamespace = rejects (steps.namespace "bad.prefix" [ ]);
    invalidLocalName = rejects (steps.namespace "local" [ { name = "bad.name"; } ]);
    duplicateInsertion = rejects (
      steps.insertAfter "json-c.configure" [ { name = "json-c.build"; } ] original
    );
    invalidReplacement = rejects (steps.replace "json-c.configure" (_: { name = "invalid"; }) original);
    duplicateReplacement = rejects (
      steps.replace "json-c.configure" (old: old // { name = "json-c.build"; }) original
    );
    invalidInputCannotBeRepaired = rejects (
      steps.delete "json-c.check" (original ++ [ { name = "json-c.check"; } ])
    );
    prefixDemandStillValidatesSuffix = failsNames (
      steps.insertBefore "json-c.configure" [ { name = "custom.first"; } ] (
        original
        ++ [
          {
            name = "json-c.check";
            enabled = false;
          }
        ]
      )
    );
    appendValidatesInput = rejects (steps.append [ ] (original ++ [ { name = "json-c.check"; } ]));
    appendValidatesResult = rejects (steps.append [ { name = "json-c.check"; } ] original);
    activeRunShape = rejects (
      steps.active [
        {
          name = "bad.run";
          run = 1;
        }
      ]
    );
    activeMissingRun = rejects (steps.active [ { name = "bad.run"; } ]);
    activeToolsShape = rejects (
      steps.active [
        {
          name = "bad.tools";
          tools = { };
          run = "";
        }
      ]
    );
    activeLibrariesShape = rejects (
      steps.active [
        {
          name = "bad.libraries";
          libraries = "";
          run = "";
        }
      ]
    );
    activeEnvShape = rejects (
      steps.active [
        {
          name = "bad.env";
          env = [ ];
          run = "";
        }
      ]
    );
    activeEnvValueShape = rejects (
      steps.active [
        {
          name = "bad.env";
          env = {
            X = 1;
          };
          run = "";
        }
      ]
    );
    activeCwdShape = rejects (
      steps.active [
        {
          name = "bad.cwd";
          cwd = [ ];
          run = "";
        }
      ]
    );
    activeElementsRemainLazy =
      names (
        steps.active [
          {
            name = "lazy.elements";
            tools = [ boom ];
            libraries = [ boom ];
            run = "";
            metadata = boom;
          }
        ]
      ) == [ "lazy.elements" ];
  };
  failed = builtins.filter (name: !checks.${name}) (builtins.attrNames checks);
in
assert
  failed == [ ] || throw "TVP build step contracts failed: ${builtins.concatStringsSep ", " failed}";
checks
