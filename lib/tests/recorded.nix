# Recorded filesystem/ABI checks retain logs and status directories. Construction
# and metadata still follow the current package context; only comparison differs.
{
  package,
  name,
  script,
  tools ? [ ],
  libraries ? [ ],
}:
(package.testContext.mkTest {
  inherit
    package
    name
    tools
    libraries
    ;
  script = ":";
  expected = "";
}).editSteps
  (map (step: if step.name == "test.compare" then step // { run = script; } else step))
