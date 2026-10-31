{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  api = tvp.lib.packages;
  release =
    version:
    pkgs.runCommand "selector-release-${version}" {
      inherit version;
      pname = "probe";
      outputs = [
        "out"
        "bin"
        "dev"
      ];
    } ''mkdir -p "$out" "$bin" "$dev"'';
  catalogue =
    pname: versions:
    let
      canonical = lib.listToAttrs (
        map (
          version:
          lib.nameValuePair (tvp.lib.versions.attrName pname version) (
            api.tagSelection {
              namespace = "canonical";
              selector = tvp.lib.versions.attrName pname version;
              kind = "exact";
            } (release version)
          )
        ) versions
      );
    in
    canonical
    // api.mkAliases {
      inherit pname canonical;
      versionTable = lib.genAttrs versions (_: { });
    };
  before = catalogue "probe" [
    "0.2.1"
    "1.2.3"
    "2.0.0"
  ];
  after = catalogue "probe" [
    "0.2.1"
    "1.2.3"
    "1.2.4"
    "2.0.0"
  ];
  letters = catalogue "openssl" [
    "1.1.1"
    "1.1.1w"
  ];
  patches = catalogue "ruby" [
    "2.0.0-p0"
    "2.0.0-p648"
  ];
  dates = catalogue "dated" [
    "2026.01.01"
    "2026.01.02"
  ];
  consumer =
    dependency:
    (api.mkVersions {
      pname = "consumer";
      infra = { };
      versionTable."1.0" = {
        sha256 = "unused";
        def = {
          name = "1.0";
          base = {
            name = "test";
            inherit (pkgs) stdenv;
          };
          builder = ./selector-builder.nix;
          deps = {
            inherit dependency;
          };
        };
      };
    }).consumer_1_0;
  lazyNames = builtins.attrNames (
    api.mkAliases {
      pname = "lazy";
      versionTable."1.2.3" = { };
      canonical = throw "alias names forced canonical derivations";
    }
  );
  exact = api.tagSelection {
    namespace = "canonical";
    selector = "probe_1_2_3";
    kind = "exact";
  } before.probe_1_2_3;
  checks = {
    sameVersionDifferentIntent =
      before.probe_1.version == exact.version
      && before.probe_1.__tvpSelection.kind == "major"
      && exact.__tvpSelection.kind == "exact";
    advancing =
      before.probe_1_2.version == "1.2.3"
      && after.probe_1_2.version == "1.2.4"
      && (consumer before.probe_1_2).drvPath != (consumer after.probe_1_2).drvPath;
    immutable =
      (consumer before.probe_1_2_3).drvPath == (consumer after.probe_1_2_3).drvPath
      && before.probe_2.drvPath == after.probe_2.drvPath;
    shadow =
      letters.openssl_1_1_1.version == "1.1.1w" && letters.openssl_1_1_1.__tvpSelection.kind == "finer";
    patchlevels = patches.ruby_2_0_0.version == "2.0.0-p648";
    calendar = dates.dated_2026_01.version == "2026.01.02";
    majorZero =
      before.probe_0.__tvpSelection.kind == "major" && before.probe_0_2.__tvpSelection.kind == "minor";
    outputProjection =
      (lib.getDev before.probe_1).__tvpSelection.selector == "probe_1"
      && before.probe_1.bin.__tvpSelection.kind == "major"
      && (lib.getDev before.probe_1).outputName == "dev";
    overrideIntent = (before.probe_1.overrideAttrs (_: { })).__tvpSelection.kind == "override";
    dependencyCapture =
      (consumer before.probe_1).tvp.declaredDependencies.dependency.__tvpSelection.kind == "major";
    explicitSingleCandidateLine =
      let
        aliases =
          versions:
          api.mkAliases {
            pname = "short";
            lines = [ "6_2" ];
            versionTable = lib.genAttrs versions (_: { });
            canonical = lib.listToAttrs (
              map (
                version: lib.nameValuePair (tvp.lib.versions.attrName "short" version) (release version)
              ) versions
            );
          };
        old = aliases [ "6.2" ];
        new = aliases [
          "6.2"
          "6.2.1"
          "6.3"
        ];
      in
      old.short_6_2.__tvpSelection.kind == "minor"
      && old.short_6_2.version == "6.2"
      && new.short_6_2.version == "6.2.1";
    siblingProjection =
      (lib.getDev before.probe_1.bin).__tvpSelection.selector == "probe_1"
      && before.probe_1.bin.out.__tvpSelection.kind == "major";
    customAlias =
      let
        a = api.mkAliases {
          pname = "custom";
          versionTable = { };
          canonical = { };
          overrides.custom-choice = api.withConstraint { reason = "Explicit fixture choice"; } (release "1");
        };
      in
      a.custom-choice.__tvpSelection.kind == "override"
      && a.custom-choice.__tvpSelection.operation == "alias-override"
      && a.custom-choice.__tvpSelection.reason == "Explicit fixture choice";
    projectedOverride = (before.probe_1.bin.overrideAttrs (_: { })).__tvpSelection.kind == "override";
    overrideMethod =
      ((consumer before.probe_1).override { dependency = after.probe_1; }).__tvpSelection.kind
      == "override";
    noAliasCycles =
      lazyNames == [
        "lazy"
        "lazy_1"
        "lazy_1_2"
      ];
    identityNeutral = (release "1.2.3").drvPath == before.probe_1_2_3.drvPath;
  };
  failed = lib.attrNames (lib.filterAttrs (_: value: !value) checks);
in
if failed != [ ] then
  throw "TVP selector contracts failed: ${lib.concatStringsSep ", " failed}"
else
  pkgs.writeText "tvp-dependency-selector-contracts.json" (builtins.toJSON checks)
