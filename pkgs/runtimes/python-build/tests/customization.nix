# Pure API contracts belong to this public recipe; historical suites stay intact.
{ package }:
let
  p = package;
  force = q: builtins.tryEval (builtins.deepSeq q.drvPath true);
  equal = q: q.drvPath == p.drvPath;
  source = p.override { src = builtins.toFile "customization-source" "explicit source control"; };
  step = name: q: builtins.head (builtins.filter (s: s.name == name) q.buildSteps);
  has =
    needle: value:
    let
      text = builtins.unsafeDiscardStringContext value;
    in
    builtins.replaceStrings [ (builtins.unsafeDiscardStringContext needle) ] [ "" ] text != text;
  profileBase = p.override { disabledModules = [ "_crypt" ]; };
  addedModules = profileBase.edit (s: s // { disabledModules = s.disabledModules ++ [ "math" ]; });
  removedModules = addedModules.edit (
    s:
    s
    // {
      disabledModules = builtins.filter (name: name != "_crypt") s.disabledModules;
    }
  );
  results = [
    (
      addedModules.tvp.disabledModules == [
        "_crypt"
        "math"
      ]
    )
    (removedModules.tvp.disabledModules == [ "math" ])
    (has " math" (step "python.prepare" addedModules).run)
    (has " math" (step "test.compare" addedModules.tests.profile).run)
    (!(has " _crypt" (step "python.prepare" removedModules).run))
    (!(has " _crypt" (step "test.compare" removedModules.tests.profile).run))
    (has " math" (step "python.prepare" removedModules).run)
    (has " math" (step "test.compare" removedModules.tests.profile).run)
    (equal (p.override { }))
    (equal (p.override (_: { })))
    (equal (p.edit (s: s)))
    (equal (p.editSteps (s: s)))
    (equal (p.editRuntime (r: r)))
    (!(force (p.override { unknownArgument = true; })).success)
    (!(force (p.editSteps (s: s ++ [ (builtins.head s) ]))).success)
    (source.drvPath != p.drvPath)
    ((step "source.unpack" source).run != (step "source.unpack" p).run)
    (
      (p.override { bash = p.specification.coreutils; }).tests.version.drvPath != p.tests.version.drvPath
    )
    (
      (step "python.prepare" (p.override { disabledModules = [ ]; })).run != (step "python.prepare" p).run
    )
  ];
in
assert builtins.all (x: x) results;
"customization"
