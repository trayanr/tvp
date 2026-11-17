# Resource budgets belong to Nix, including when a release inherits its builder.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  openssl = lib.filterAttrs (
    name: package: lib.hasPrefix "openssl_" name && (package.tvp.status.level or "ok") != "broken"
  ) tvp.canonical;
  commands =
    package:
    builtins.filter (
      step:
      builtins.elem step.name [
        "openssl.build"
        "openssl.install"
      ]
    ) package.buildSteps;
  results = {
    php = import ../../pkgs/runtimes/php/concurrency-contracts.nix { inherit lib tvp; };
    opensslBuildAndInstallUseNixCores = lib.all (
      package:
      commands package != [ ]
      && lib.all (step: lib.hasInfix "NIX_BUILD_CORES" step.run && !(lib.hasInfix "-j1 " step.run)) (
        commands package
      )
    ) (builtins.attrValues openssl);
  };
in
assert results.opensslBuildAndInstallUseNixCores;
results
