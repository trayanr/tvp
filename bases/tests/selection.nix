# Public base families select genuine source-built compiler generations.
{
  pkgs,
  tvp,
  construction,
}:
let
  inherit (pkgs) lib;
  bases = tvp.bases;
  contexts = tvp.__legacyBases;
  selections = [
    {
      alias = "gcc_4";
      exact = "gcc_4_9_4";
      version = "4.9.4";
    }
    {
      alias = "gcc_9";
      exact = "gcc_9_5_0";
      version = "9.5.0";
    }
    {
      alias = "gcc_13";
      exact = "gcc_13_3_0";
      version = "13.3.0";
    }
    {
      alias = "gcc_16";
      exact = "gcc_16_2_0";
      version = "16.2.0";
    }
  ];
  contracts = {
    selectors =
      builtins.attrNames bases == [
        "default"
        "gcc_13"
        "gcc_13_3_0"
        "gcc_16"
        "gcc_16_2_0"
        "gcc_4"
        "gcc_4_9_4"
        "gcc_9"
        "gcc_9_5_0"
      ];
    majorAliases = lib.all (
      x:
      bases.${x.alias}.full.compiler.drvPath == bases.${x.exact}.full.compiler.drvPath
      && bases.${x.alias}.full.compiler.version == x.version
    ) selections;
    default = bases.default.compiler.drvPath == bases.gcc_16.full.compiler.drvPath;
    actualStages =
      lib.all (x: builtins.attrNames bases.${x.alias} == [ "full" ]) (lib.take 3 selections)
      &&
        builtins.attrNames bases.gcc_16 == [
          "full"
          "reduced"
          "runtime"
          "seed"
        ];
    ownedContexts = lib.all (
      x:
      let
        b = bases.${x.alias}.full;
      in
      !(b ? stdenv)
      && b.tools.gcc.drvPath == b.compiler.drvPath
      && b.tools.bash.drvPath == b.shell.drvPath
    ) selections;
    sourceCompilers = lib.all (
      x:
      let
        c = bases.${x.alias}.full.compiler.tvp.deps.compiler;
      in
      c ? artifact && c ? specification && c.artifact.drvPath != c.drvPath
    ) selections;
    retainedRecipesUseSameProviders = lib.all (
      x:
      let
        b = contexts.${x.exact};
      in
      b.stdenv.cc.drvPath == bases.${x.alias}.full.compiler.drvPath
      && b.ownedBase.compiler.drvPath == b.stdenv.cc.drvPath
    ) selections;
    noRetiredConstructionVariants = construction.variants == { };
    noLegacyPublicAPI = !(tvp ? baseTiers) && !(tvp ? bootstrap) && !(tvp ? recipes);
    historicalStatuses = lib.all (p: p.tvp.status.level == "broken" && p ? artifact) (
      map (n: tvp.canonical.${n}) [
        "readline_2_0"
        "zlib_0_71"
        "zlib_0_79"
        "zlib_0_8"
        "zlib_0_9"
        "zlib_0_91"
        "zlib_0_92"
        "zlib_0_93"
        "zlib_0_94"
        "zlib_0_95"
        "zlib_0_99"
      ]
    );
    targetLibc =
      tvp.packages.gcc_13_3_0.specification.glibc.drvPath == bases.gcc_16.full.compiler.libc.drvPath;
  };
  failed = lib.attrNames (lib.filterAttrs (_: ok: !ok) contracts);
in
assert failed == [ ] || throw "TVP base selection: ${lib.concatStringsSep ", " failed}";
pkgs.writeText "tvp-source-base-selections" (builtins.toJSON contracts)
