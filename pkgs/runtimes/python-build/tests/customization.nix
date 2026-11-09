# Pure API contracts belong to this public recipe; historical suites stay intact.
{ package }:
let
  p = package;
  force = q: builtins.tryEval (builtins.deepSeq q.drvPath true);
  equal = q: q.drvPath == p.drvPath;
  source = p.override { src = builtins.toFile "customization-source" "explicit source control"; };
  step = name: q: builtins.head (builtins.filter (s: s.name == name) q.buildSteps);
  results = [
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
