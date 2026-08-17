{
  system ? "x86_64-linux", # currently unused?
  config ? { },
  pkgs, # TODO: nixpkgs check and abort if not or auto import channel
}:
let
  tvpLib = import ./lib { inherit (pkgs) lib; };

  packages = import ./pkgs { inherit pkgs tvp; };

  # Repo-wide invariants only. A package's own tests live at <pkg>.tests.*.
  checks = {
    packages-evaluate =
      let
        drvs = pkgs.lib.mapAttrsToList (
          name: pkg: "${name} ${builtins.unsafeDiscardStringContext pkg.drvPath}"
        ) packages;
      in
      pkgs.runCommand "tvp-packages-evaluate" { manifest = builtins.concatStringsSep "\n" drvs; } ''
        printf '%s\n' "$manifest" > "$out"
      '';

    # Only .nix files are copied, so local-only files never reach the store.
    formatting =
      let
        inherit (pkgs.lib) fileset;
        src = fileset.toSource {
          root = ./.;
          fileset = fileset.fileFilter (f: f.hasExt "nix") ./.;
        };
      in
      pkgs.runCommand "tvp-check-formatting" { nativeBuildInputs = [ pkgs.nixfmt-rfc-style ]; } ''
        nixfmt --check $(find ${src} -name '*.nix') 2>&1 | tee "$out"
        test ! -s "$out"
      '';
  };

  testBatches = builtins.mapAttrs (
    name: pkg:
    tvpLib.tests.mkBatch {
      inherit pkgs name;
      suite = pkg.tests;
    }
  ) (pkgs.lib.filterAttrs (_: pkg: pkg ? tests && pkg.tests != { }) packages);

  tvp = {
    inherit packages checks testBatches;
    lib = tvpLib;
  };
in
tvp
