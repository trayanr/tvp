# Pure API contracts belong to this ordinary family; frozen suites stay intact.
{ package }:
let
  p = package;
  force = q: builtins.tryEval (builtins.deepSeq q.drvPath true);
  equal = q: q.drvPath == p.drvPath;
  sameProduction = q: q.artifact.drvPath == p.artifact.drvPath && equal q;
  source = p.override { src = builtins.toFile "customization-source" "explicit source control"; };
  step =
    name: q:
    if name == "isl.check" then
      q.specification.upstreamCheck
    else
      builtins.head (builtins.filter (s: s.name == name) q.buildSteps);
  has =
    needle: value:
    let
      text = builtins.unsafeDiscardStringContext value;
    in
    builtins.replaceStrings [ (builtins.unsafeDiscardStringContext needle) ] [ "" ] text != text;
  replacementGmp = p.specification.gmp.editSteps (
    xs:
    xs
    ++ [
      {
        name = "contract.gmp-provider";
        run = "true";
      }
    ]
  );
  editedGmp = p.edit (s: s // { gmp = replacementGmp; });
  runtimeGmp = p.editRuntime (r: r // { libraries = [ replacementGmp ]; });
  loadedLibrary = (step "test.compare" editedGmp.tests.loaded-library).run;
  runtimeLoaded = (step "test.compare" runtimeGmp.tests.loaded-library).run;
  disabled = p.override { doCheck = false; };
  restored = disabled.edit (s: s // { doCheck = true; });
  shell = p.edit (s: s // { base = s.base.override { shell = p.specification.coreutils; }; });
  results = [
    (replacementGmp.version == p.specification.gmp.version)
    (replacementGmp.outPath != p.specification.gmp.outPath)
    (has (toString replacementGmp + "/lib/libgmp.so") loadedLibrary)
    (!(has (toString p.specification.gmp + "/lib/libgmp.so") loadedLibrary))
    (editedGmp.tests.loaded-library.drvPath != p.tests.loaded-library.drvPath)
    (has (toString replacementGmp + "/lib/libgmp.so") runtimeLoaded)
    (runtimeGmp.artifact.drvPath == p.artifact.drvPath && !equal runtimeGmp)
    (p.meta.description == "Integer sets and relations library for polyhedral compilation")
    (p.meta.license.spdxId == "MIT")
    (equal (p.override { }))
    (equal (p.override (_: { })))
    (equal (p.edit (s: s)))
    (equal (p.editSteps (s: s)))
    (equal (p.editRuntime (r: r)))
    (!(force (p.override { unknownArgument = true; })).success)
    (!(force (p.editSteps (s: s ++ [ (builtins.head s) ]))).success)
    (source.drvPath != p.drvPath)
    ((step "source.unpack" source).run != (step "source.unpack" p).run)
    (shell.tests.version.drvPath != p.tests.version.drvPath)
    (!(step "isl.check" disabled).enabled)
    ((step "isl.check" restored).enabled)
    (!(step "isl.check" (p.edit (s: s // { doCheck = false; }))).enabled)
    (sameProduction disabled && !(disabled.tests ? upstream))
    (!(builtins.any (s: s.name == "isl.check") p.buildSteps))
  ];
in
assert builtins.all (x: x) results;
"customization"
