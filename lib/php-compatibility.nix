{ lib }:
let
  matches =
    range: version:
    (!(range ? exact) || version == range.exact)
    && (!(range ? min) || builtins.compareVersions version range.min >= 0)
    && (!(range ? before) || builtins.compareVersions version range.before < 0)
    && (!(range ? max) || builtins.compareVersions version range.max <= 0);
  checkRequirements =
    requirements:
    assert
      requirements == { }
      || (
        builtins.isString (requirements.reason or null)
        && requirements.reason != ""
        && builtins.isString (requirements.source or null)
        && requirements.source != ""
        && builtins.any (key: requirements ? ${key}) [
          "exact"
          "min"
          "before"
          "max"
        ]
      )
      || throw "PHP hard limits require a version bound, a reason, and an upstream source";
    requirements;
  isBuiltIn = policy: php: policy ? builtIn && matches (checkRequirements policy.builtIn) php;
in
{
  inherit matches isBuiltIn;
  report =
    {
      versionTable,
      phpVersions,
      policy ? {
        kind = "independent";
      },
    }:
    let
      mixed = policy.kind == "mixed";
      bundled =
        php: policy.kind == "bundled" || (mixed && matches (checkRequirements policy.bundled) php);
      standalone = lib.filterAttrs (
        _: entry: !mixed || !(entry.def.opts.phpCompatibility ? exact)
      ) versionTable;
      classify =
        php: release: declared: rawRequirements:
        let
          requirements = checkRequirements rawRequirements;
          allowed = matches requirements php;
          packaged = declared != null && matches declared php;
        in
        assert
          !packaged
          || allowed
          || throw "PHP ${php} is declared supported by extension ${release} outside its hard limits";
        {
          inherit php release;
          state =
            if !allowed then
              "incompatible"
            else if packaged then
              "packaged"
            else
              "gap";
          reason =
            if !allowed then
              requirements.reason
            else if !packaged then
              "No declared package for this PHP and extension release"
            else
              null;
          source = if !allowed then requirements.source else null;
        };
      rows = lib.concatMap (
        php:
        if isBuiltIn policy php then
          assert !(versionTable ? ${php}) || throw "PHP ${php} already includes this extension in the engine";
          [
            (
              {
                inherit php;
                release = php;
                state = "builtin";
                inherit (policy.builtIn) reason source;
              }
              // lib.optionalAttrs mixed { kind = "bundled"; }
            )
          ]
        else if bundled php then
          [
            (
              classify php php (
                if versionTable ? ${php} then versionTable.${php}.def.opts.phpCompatibility else null
              ) (policy.requirements or { })
              // lib.optionalAttrs mixed { kind = "bundled"; }
            )
          ]
        else
          lib.mapAttrsToList (
            release: entry:
            classify php release entry.def.opts.phpCompatibility (entry.def.phpRequirements or { })
            // lib.optionalAttrs mixed { kind = "independent"; }
          ) standalone
      ) (builtins.attrValues phpVersions);
    in
    assert builtins.elem policy.kind [
      "independent"
      "bundled"
      "mixed"
    ];
    {
      inherit (policy) kind;
      inherit rows;
    };
}
