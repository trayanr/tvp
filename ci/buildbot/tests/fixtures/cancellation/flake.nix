{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/@revision@";
  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      kept = pkgs.runCommand "tvp-cancel-kept-@nonce@" { } ''printf kept > "$out"'';
      blocked = pkgs.runCommand "tvp-cancel-blocked-@nonce@" { keptInput = kept; } ''
        echo "cancellation fixture started" >&2
        sleep 120
        printf done > "$out"
      '';
      aggregate = pkgs.linkFarm "tvp-cancel-all-@nonce@" [
        {
          name = "kept";
          path = kept;
        }
        {
          name = "blocked";
          path = blocked;
        }
      ];
      job = name: package: {
        inherit name;
        drv = builtins.unsafeDiscardOutputDependency package.drvPath;
        outputs = [ (builtins.unsafeDiscardStringContext package.outPath) ];
        tests = [ ];
      };
    in
    {
      checks.${system}.kept = kept;
      graph = {
        schema = 1;
        entries.kept = {
          drv = builtins.unsafeDiscardStringContext kept.drvPath;
          out = builtins.unsafeDiscardStringContext kept.outPath;
        };
      };
      testPlans.${system} = pkgs.writeText "tvp-cancel-plan.json" (
        builtins.toJSON {
          schema = 1;
          inherit system;
          source = self.outPath;
          revision = self.rev or null;
          aggregate = builtins.unsafeDiscardOutputDependency aggregate.drvPath;
          jobs = [
            (job "kept" kept)
            (job "blocked" blocked)
          ];
          skipped = [ ];
        }
      );
    };
}
