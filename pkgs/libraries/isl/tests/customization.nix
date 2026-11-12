# Pure API contracts belong to this public recipe; historical suites stay intact.
{ package }:
let
  p = package;
  force = q: builtins.tryEval (builtins.deepSeq q.drvPath true);
  equal = q: q.drvPath == p.drvPath;
  source = p.override { src = builtins.toFile "customization-source" "explicit source control"; };
  step = name: q: if name == "isl.check" then q.specification.upstreamCheck else builtins.head (builtins.filter (s: s.name == name) q.buildSteps);
  has =
    needle: value:
    let
      text = builtins.unsafeDiscardStringContext value;
    in
    builtins.replaceStrings [ (builtins.unsafeDiscardStringContext needle) ] [ "" ] text != text;
  replacementGmp = p.specification.libraries.gmp.editSteps (
    xs:
    xs
    ++ [
      {
        name = "contract.gmp-provider";
        run = "true";
      }
    ]
  );
  editedGmp = p.edit (
    s:
    s
    // {
      libraries = s.libraries // {
        gmp = replacementGmp;
      };
    }
  );
  loadedLibrary = (step "test.compare" editedGmp.tests.loaded-library).run;
  results = [
    (replacementGmp.version == p.specification.libraries.gmp.version)
    (replacementGmp.outPath != p.specification.libraries.gmp.outPath)
    (has (toString replacementGmp + "/lib/libgmp.so") loadedLibrary)
    (!(has (toString p.specification.libraries.gmp + "/lib/libgmp.so") loadedLibrary))
    (editedGmp.tests.loaded-library.drvPath != p.tests.loaded-library.drvPath)
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
    (
      (p.override { bash = p.specification.coreutils; }).tests.version.drvPath != p.tests.version.drvPath
    )
    (!(step "isl.check" (p.override { doCheck = false; })).enabled)
    ((step "isl.check" (
      (p.override { doCheck = false; }).edit (
        s:
        s
        // {
          tvp = s.tvp // {
            features = s.tvp.features // {
              doCheck = true;
            };
          };
        }
      )
    )).enabled
    )
    (
      !(step "isl.check" (
        p.edit (
          s:
          s
          // {
            tvp = s.tvp // {
              features = s.tvp.features // {
                doCheck = false;
              };
            };
          }
        )
      )).enabled
    )
  ];
in
assert builtins.all (x: x) results;
"customization"
