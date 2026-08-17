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

    # Makes "untested" unrepresentable rather than merely discouraged. A broken
    # package is exempt because it has no build to test — and it can only be
    # broken by declaring a reason and a fix, so that exemption is not a hiding
    # place.
    every-package-tested =
      let
        buildable = pkgs.lib.filterAttrs (_: p: (p.tvp.status.level or "ok") != "broken") packages;
        untested = pkgs.lib.filterAttrs (_: p: !(p ? tests) || p.tests == { }) buildable;
      in
      if untested == { } then
        pkgs.runCommand "tvp-check-every-package-tested"
          { tested = toString (builtins.length (builtins.attrNames buildable)); }
          ''
            printf '%s buildable packages, all with tests\n' "$tested" > "$out"
          ''
      else
        throw "TVP: packages with no tests: ${pkgs.lib.concatStringsSep ", " (pkgs.lib.attrNames untested)}";

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

  testBatches =
    builtins.mapAttrs
      (
        name: pkg:
        tvpLib.tests.mkBatch {
          inherit pkgs name;
          suite = pkg.tests;
        }
      )
      (
        pkgs.lib.filterAttrs (
          _: pkg: pkg ? tests && pkg.tests != { } && (pkg.tvp.status.level or "ok") != "broken"
        ) packages
      );

  # Deliberately not in `packages`: that attribute is the canonical package
  # universe, and tooling in it would also be subject to every-package-tested.
  tools = {
    provenance = pkgs.callPackage ./tools/provenance.nix {
      inherit packages;
      inherit tvpLib;
    };
    upstream = pkgs.callPackage ./tools/upstream.nix {
      inherit packages;
      inherit tvpLib;
    };
    status = pkgs.callPackage ./tools/status.nix {
      inherit packages;
      inherit tvpLib;
    };
  };

  tvp = {
    inherit
      packages
      checks
      testBatches
      tools
      ;
    lib = tvpLib;
  };
in
tvp
