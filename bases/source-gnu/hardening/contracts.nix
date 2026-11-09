{ candidate, pilots }:
let
  inherit (candidate) base;
  policy = import ../../../lib/hardening-policy.nix;
  rejects = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  empty = candidate.withHardening { };
  disabled = candidate.withHardening {
    enable = [ "format" ];
    disable = [ "format" ];
  };
  off = pilots.zip.override { base = empty; };
  edited = pilots.zip.edit (
    s:
    s
    // {
      hardeningDisable = [
        "format"
        "fortify"
      ];
    }
  );
  planText = package: builtins.concatStringsSep "\n" (map (s: s.run) package.buildSteps);
  results = {
    emptyExact = empty == base && disabled == base;
    defaults =
      (policy {
        defaults = [
          "pic"
          "relro"
        ];
      }).selected == [
        "pic"
        "relro"
      ];
    composition =
      (policy {
        defaults = [
          "pic"
          "relro"
        ];
        enable = [
          "fortify"
          "pic"
        ];
        disable = [ "relro" ];
      }).selected == [
        "fortify"
        "pic"
      ];
    unknown = rejects (policy {
      enable = [ "pie" ];
    });
    wrongType = rejects (policy {
      disable = "format";
    });
    noCompilerChurn =
      pilots.base.compiler.underlyingDriver == base.compiler
      && pilots.base.compiler.underlyingBintools == base.compiler.bintools;
    runtimeExact = pilots.base.runtimeDirectories == base.runtimeDirectories;
    optedOutExact = off.drvPath == (pilots.zip.override { inherit base; }).drvPath;
    unknownRecipeException = rejects (pilots.zip.override { hardeningDisable = [ "pie" ]; }).drvPath;
    editedUnknownRecipeException =
      rejects
        (pilots.unzip.edit (s: s // { hardeningDisable = [ "unknown" ]; })).drvPath;
    formatException = builtins.elem "format" pilots.zip.specification.hardeningDisable;
    adapterOverride =
      (pilots.base.compiler.override { driver = base.compiler; }).drvPath == pilots.base.compiler.drvPath;
    adapterPolicyOverride =
      (pilots.base.compiler.override { policy.enable = [ "fortify" ]; }).defaultHardeningFlags
      == [ "fortify" ];
    adapterPolicyUnknown =
      rejects
        (pilots.base.compiler.override { policy.enable = [ "pie" ]; }).defaultHardeningFlags;
    adapterEdit =
      (pilots.base.compiler.edit (
        s:
        s
        // {
          python = s.python // {
            outPath = "/deliberately-missing-python";
          };
        }
      )).drvPath != pilots.base.compiler.drvPath;
    linkerOverride =
      (pilots.base.compiler.bintools.override { bintools = base.compiler.bintools; }).drvPath
      == pilots.base.compiler.bintools.drvPath;
    noOp =
      (pilots.zip.override { }).drvPath == pilots.zip.drvPath
      && (pilots.zip.edit (s: s)).drvPath == pilots.zip.drvPath;
    projection = (pilots.zip.out.override { base = empty; }).drvPath == off.drvPath;
    disableLowered =
      builtins.match ".*NIX_HARDENING_ENABLE='bindnow pic relro stackprotector strictoverflow'.*" (
        planText edited
      ) != null;
    overrideEffective = edited.drvPath != pilots.zip.drvPath;
  };
  failures = builtins.filter (name: !results.${name}) (builtins.attrNames results);
in
assert failures == [ ] || throw "Hardening contracts: ${builtins.concatStringsSep ", " failures}";
results
