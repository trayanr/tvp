# Internal pure build-step editing. No runner or public API yet.
# Plans are ordered record lists. Names are context-free, dot-separated components
# ([a-zA-Z][a-zA-Z0-9_-]*), with at least a namespace and a local name.
# Edits: insertBefore/insertAfter target records plan; replace target (old: ...)
# plan; append records plan; delete target plan. All validate the complete input
# and result, including disabled records. replace preserves only what its callback
# returns: use old: old // { run = ...; } to retain enabled and other fields.
let
  fail = message: throw "TVP build steps: ${message}";
  component = name: builtins.isString name && builtins.match "[a-zA-Z][a-zA-Z0-9_-]*" name != null;
  validName =
    name:
    builtins.isString name
    && !builtins.hasContext name
    && builtins.match "[a-zA-Z][a-zA-Z0-9_-]*(\\.[a-zA-Z][a-zA-Z0-9_-]*)+" name != null;
  checkName =
    name:
    if validName name then name else fail "expected a namespaced name (for example json-c.configure)";
  validate =
    plan:
    if !builtins.isList plan then
      fail "expected an ordered list of records"
    else
      builtins.seq (builtins.foldl' (
        seen: step:
        if !builtins.isAttrs step then
          fail "expected a step record"
        else if !(step ? name) then
          fail "step is missing name"
        else
          let
            name = checkName step.name;
          in
          if !builtins.isBool (step.enabled or true) then
            fail "${name}: enabled must be a Boolean"
          else if builtins.hasAttr name seen then
            fail "duplicate name '${name}'"
          else
            seen // { ${name} = true; }
      ) { } plan) plan;
  edit =
    target: transform: plan:
    let
      checked = validate plan;
      name = checkName target;
    in
    builtins.seq checked (
      if !builtins.any (step: step.name == name) checked then
        fail "missing target '${name}'"
      else
        validate (builtins.concatMap (step: if step.name == name then transform step else [ step ]) checked)
    );
  # Defaults are data only. "." denotes the future prepared source root; this
  # module implements neither cwd changes nor shell/environment isolation.
  defaults = {
    enabled = true;
    cwd = ".";
    tools = [ ];
    libraries = [ ];
    env = { };
  };
  activeShape =
    record:
    let
      step = defaults // record;
    in
    if !builtins.isString step.cwd then
      fail "${step.name}: cwd must be a string"
    else if !builtins.isList step.tools || !builtins.isList step.libraries then
      fail "${step.name}: tools and libraries must be lists"
    else if !builtins.isAttrs step.env then
      fail "${step.name}: env must be an attribute set"
    else if !builtins.all builtins.isString (builtins.attrValues step.env) then
      fail "${step.name}: env values must be strings"
    else if !(step ? run) || !builtins.isString step.run then
      fail "${step.name}: run must be a string"
    else
      step;
in
{
  inherit validate;
  namespace =
    prefix: records:
    if !component prefix || builtins.hasContext prefix then
      fail "namespace must be a context-free name component"
    else if !builtins.isList records then
      fail "namespace expects a list of locally named records"
    else
      validate (
        map (
          step:
          if !builtins.isAttrs step || !(step ? name) then
            fail "namespace expects locally named records"
          else if !component step.name || builtins.hasContext step.name then
            fail "local name must be a context-free name component"
          else
            step // { name = "${prefix}.${step.name}"; }
        ) records
      );
  insertBefore = target: records: edit target (old: records ++ [ old ]);
  insertAfter = target: records: edit target (old: [ old ] ++ records);
  replace = target: update: edit target (old: [ (update old) ]);
  append = records: plan: builtins.seq (validate plan) (validate (plan ++ records));
  delete = target: edit target (_: [ ]);

  # Call once after edits, before collecting inputs or constructing derivations.
  # Validate names/enabled eagerly; check active field shapes but never deep-force
  # records, tool/library elements or additional metadata. Disabled payloads are
  # never inspected. Strings retain their original Nix dependency contexts.
  active =
    plan:
    let
      selected = map activeShape (builtins.filter (step: step.enabled or true) (validate plan));
    in
    builtins.seq (builtins.foldl' (ok: step: builtins.seq step ok) true selected) selected;
}
