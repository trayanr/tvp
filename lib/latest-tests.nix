# Pure projection of ordinary family aliases onto existing own-test batches.
# Only the selected release's tests are inspected; historical outputs stay lazy.
{ lib }:
{
  canonical,
  packages,
  batches,
}:
let
  plain = builtins.unsafeDiscardStringContext;
  fail = message: throw "TVP latest tests: ${message}";
  broken = p: (p.tvp.status.level or "ok") == "broken";
  grouped = lib.groupBy (name: canonical.${name}.pname) (lib.attrNames canonical);
  supported = lib.mapAttrs (
    _: names: builtins.filter (name: !(broken canonical.${name})) names
  ) grouped;
  # Include selected and sibling outputs, so a projected output cannot pass as
  # the original suite just because its producer drvPath is the same.
  identity = drv: {
    drv = plain drv.drvPath;
    out = plain drv.outPath;
    outputs = map (name: plain drv.${name}.outPath) drv.outputs;
  };
  suiteIdentity = suite: lib.mapAttrs (_: identity) suite;
  families = lib.mapAttrs (
    family: names:
    let
      selected = packages.${family};
      selector = selected.__tvpSelection or { };
      job = selector.canonical or "";
      package = canonical.${job};
      batch = batches.${job};
    in
    if !(packages ? ${family}) then
      fail "missing public alias ${family}"
    else if
      (selector.namespace or null) != "packages"
      || (selector.selector or null) != family
      || (selector.pname or null) != family
      || (selector.version or null) != selected.version
      || !(builtins.elem (selector.kind or null) [
        "latest"
        "override"
      ])
      || !(builtins.elem job names)
    then
      fail "alias ${family} does not select an eligible canonical release"
    else if
      selected.pname != family
      || selected.version != package.version
      || identity selected != identity package
    then
      fail "alias ${family} disagrees with canonical ${job}"
    else if
      !(lib.all (name: builtins.compareVersions canonical.${name}.version package.version <= 0) names)
    then
      fail "alias ${family} is older than an eligible release"
    else if !(package ? tests) || package.tests == { } then
      fail "selected release ${job} has no own tests"
    else if !(batches ? ${job}) then
      fail "missing own-test batch ${job}"
    else if !(batch ? testSuite) || suiteIdentity batch.testSuite != suiteIdentity package.tests then
      fail "batch ${job} does not preserve the selected own-test suite"
    else
      {
        inherit job family;
        inherit (package) version;
        selector = builtins.fromJSON (plain (builtins.toJSON selector));
        packageDRV = plain package.drvPath;
        jobDRV = plain batch.drvPath;
        out = plain package.outPath;
        outputs = map (name: plain package.${name}.outPath) package.outputs;
      }
  ) (lib.filterAttrs (_: names: names != [ ]) supported);
  jobs = map (entry: entry.job) (lib.attrValues families);
  skipped = lib.mapAttrsToList (family: _: {
    inherit family;
    reason = "All declared releases are broken; no usable family alias or batch is required.";
    releases = map (name: {
      inherit name;
      inherit (canonical.${name}.tvp.status) reason needs;
    }) grouped.${family};
  }) (lib.filterAttrs (_: names: names == [ ]) supported);
in
# Validate even when callers only ask for batch names, not metadata values.
builtins.deepSeq families (
  if builtins.length jobs != builtins.length (lib.unique jobs) then
    fail "duplicate selected batch names"
  else
    {
      batches = lib.genAttrs jobs (job: batches.${job});
      metadata = {
        schema = "tvp.latest-tests/v1";
        inherit families skipped;
      };
    }
)
