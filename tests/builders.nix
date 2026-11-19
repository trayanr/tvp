# Builders for repository validation, separate from ordinary package construction.
{
  pkgs,
  tvp,
  base,
  legacyBase,
}:
let
  inherit (base) coreutils;
  inherit (base.platform) system;
  compatibility = tvp.lib.tests.compatibility.withBase {
    inherit pkgs;
    base = legacyBase;
  };
  owned = tvp.lib.tests.forBase {
    inherit base coreutils;
    builder = tvp.builder;
  };
in
{
  inherit (compatibility) runCommand stdenv;
  tvpTestBatch = owned.mkBatch;
  closureInfo = pkgs.closureInfo.override {
    inherit (compatibility) stdenv;
    inherit coreutils;
    inherit (tvp.packages) jq;
  };
  # A derivation preserves input contexts in generated checks and manifests.
  writeText =
    name: text:
    builtins.derivation {
      inherit name system text;
      builder = "${base.shell}/bin/bash";
      args = [
        "-euc"
        ''${coreutils}/bin/cp -- "$textPath" "$out"''
      ];
      passAsFile = [ "text" ];
      preferLocalBuild = true;
      allowSubstitutes = false;
    };
}
