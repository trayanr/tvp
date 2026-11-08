{ tvp, lib }:
let
  package = pname: version: rec {
    inherit pname version;
    drvPath = "/fixture/${pname}-${version}.drv";
    outPath = "/fixture/${pname}-${version}";
    outputs = [ "out" ];
    out = {
      inherit outPath;
    };
    tests.version = "declaration-only";
  };
  canonical = {
    widget_1_9 = package "widget" "1.9";
    widget_1_10 = package "widget" "1.10";
    widget_999 = (package "widget" "999") // {
      tvp.status.level = "broken";
    };
    rustc_1_9_0 = package "rustc" "1.9.0";
    rustc_1_97_1 = package "rustc" "1.97.1";
  };
  aliases =
    pname: versions:
    tvp.lib.packages.mkAliases {
      inherit pname canonical;
      versionTable = lib.genAttrs versions (version: {
        status.level = if version == "999" then "broken" else "ok";
      });
    };
  packages =
    (aliases "widget" [
      "1.9"
      "1.10"
      "999"
    ])
    // (aliases "rustc" [
      "1.9.0"
      "1.97.1"
    ]);
  fixture = {
    inherit canonical;
    packages = packages // {
      python_3 = "python-fixture";
    };
    android.profiles = { };
    bases.default.stdenv.mkDerivation = attrs: attrs;
  };
  make =
    universe:
    import ../default.nix {
      pkgs = {
        inherit lib;
        writeText = name: text: { inherit name text; };
      };
      tvp = universe;
      registry = [ { path = "/fixture/registered-without-context"; } ];
    };
  audits = make fixture;
  latest = audits.package-runtime-ownership-latest;
  policy = builtins.fromJSON audits.runtime-policy-latest.text;
  whole = builtins.fromJSON audits.runtime-policy.text;
  baseline = builtins.fromJSON (builtins.readFile ../runtime-baseline.json);
  mismatch = make (
    fixture
    // {
      packages = fixture.packages // {
        widget = fixture.packages.widget // {
          __tvpSelection.canonical = "widget_1_9";
        };
      };
    }
  );
  lazyOld = make (
    fixture
    // {
      canonical = canonical // {
        widget_1_9 = canonical.widget_1_9 // {
          outPath = throw "omitted historical output was forced";
        };
      };
    }
  );
  catalogue = builtins.fromJSON (
    builtins.unsafeDiscardStringContext
      (import ../../lib/test-catalogue.nix {
        pkgs = {
          inherit lib;
          writeText = name: text: { inherit name text; };
          stdenv.hostPlatform.system = "x86_64-linux";
        };
        inherit canonical packages;
        variants = { };
        batches = lib.mapAttrs (name: _: { drvPath = "/fixture/test-${name}.drv"; }) canonical;
        source = ./latest.nix;
        revision = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
      }).text
  );
in
{
  aliasesSelectSemanticLatest =
    builtins.attrNames latest.runtimeRoots == [
      "rustc_1_97_1"
      "widget_1_10"
    ];
  selectedActualRoots =
    latest.exportReferencesGraph.runtime == [
      canonical.rustc_1_97_1
      canonical.widget_1_10
    ];
  originalAllVersionRootsRetained =
    builtins.attrNames audits.package-runtime-ownership.runtimeRoots == [
      "rustc_1_97_1"
      "rustc_1_9_0"
      "widget_1_10"
      "widget_1_9"
    ];
  selectedBaselineUnchanged = policy.legacy == baseline && whole.legacy == baseline;
  selectedPolicyRoots = policy.roots == builtins.attrNames latest.runtimeRoots;
  registryRemainsContextFree =
    policy.registeredPaths == [ "/fixture/registered-without-context" ]
    && !(builtins.hasContext audits.runtime-policy-latest.text);
  mismatchedAliasRejected =
    !(builtins.tryEval (builtins.deepSeq mismatch.package-runtime-ownership-latest true)).success;
  omittedOutputsNotDemanded =
    (builtins.tryEval (builtins.deepSeq lazyOld.package-runtime-ownership-latest true)).success;
  catalogueUsesAliasVersion = catalogue.families.widget.alias.version == "1.10";
  catalogueRetainsOmittedDeclarations =
    map (r: r.version) catalogue.families.widget.versions == [
      "1.10"
      "1.9"
    ];
  catalogueOutputMappings =
    catalogue.families.widget.alias.outputs == [ canonical.widget_1_10.outPath ];
  catalogueDeclarationsDiscardContexts = !(builtins.hasContext (builtins.toJSON catalogue.families));
}
