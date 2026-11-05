# Expected failures, deliberately excluded from successful build aggregates.
{
  system ? "x86_64-linux",
}:
let
  b = import ./. { inherit system; };
  inherit (import ./adapter.nix { inherit system; }) derivationWithMeta;
  failCommand =
    name: command:
    derivationWithMeta {
      inherit name;
      builder = "${b.stage0.kaem}/bin/kaem";
      PATH = "";
      create = "${b.stage0.mescc-tools-extra}/bin/mkdir";
      args = [
        "--strict"
        "--file"
        (builtins.toFile "negative.kaem" (
          command
          + "\n"
          + ''
            ''${create} ''${out}
          ''
        ))
      ];
    };
in
{
  ambient-shell = failCommand "tvp-bootstrap-no-ambient-shell" "sh -c true";
  ambient-env = failCommand "tvp-bootstrap-no-ambient-env" "env";
  missing-stage = derivationWithMeta {
    name = "tvp-bootstrap-missing-stage";
    builder = "${b.stage0.mescc-tools}/bin/missing-M1";
    args = [ ];
  };
  wrong-stage = derivationWithMeta {
    name = "tvp-bootstrap-wrong-stage";
    builder = builtins.toFile "not-an-executable" "source data, not an earlier compiler";
    args = [ ];
  };
  # Download original bytes with the wrong expected hash. A separate name/hash
  # prevents an existing known-good FOD from bypassing this negative test.
  seed-hash = import <nix/fetchurl.nix> {
    name = "tvp-bootstrap-reject-wrong-seed-hash";
    url = (builtins.fromJSON (builtins.readFile ./provenance.json)).seed.url;
    executable = true;
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };
  seed-mutation = import <nix/fetchurl.nix> {
    name = "tvp-bootstrap-reject-mutated-seed";
    url = "file://${builtins.toFile "corrupted-seed" "corrupted seed bytes\n"}";
    executable = true;
    hash = (builtins.fromJSON (builtins.readFile ./provenance.json)).seed.narHash;
  };
  source-hash = builtins.fetchTarball {
    url = (builtins.fromJSON (builtins.readFile ./stage0-sources.json)).amd64.url;
    sha256 = "0000000000000000000000000000000000000000000000000000";
  };
}
