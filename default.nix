{
  system ? "x86_64-linux", # currently unused?
  config ? { },
  pkgs, # TODO: nixpkgs check and abort if not or auto import channel
}:
let
  tvpLib = import ./lib { inherit (pkgs) lib; };

  # The ground packages are built on. Defined before `packages` because every
  # version table names one, and exposed on `tvp` so a version table can reach
  # it the same way it reaches `tvp.packages`.
  bases = import ./bases { inherit pkgs tvpLib; };

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

    every-base-tested =
      let
        untested = pkgs.lib.filterAttrs (_: b: !(b ? tests) || b.tests == { }) bases;
      in
      if untested == { } then
        pkgs.runCommand "tvp-check-every-base-tested"
          { tested = toString (builtins.length (builtins.attrNames bases)); }
          ''
            printf '%s base attributes, all with tests\n' "$tested" > "$out"
          ''
      else
        throw "TVP: bases with no tests: ${pkgs.lib.concatStringsSep ", " (pkgs.lib.attrNames untested)}";

    # Holds bases/stdenv/make-derivation.nix at "vendored verbatim": TVP's
    # mkDerivation must still compute exactly what nixpkgs' does. Trimming what
    # TVP does not use is a deliberate, cache-invalidating step, and this check
    # failing is what distinguishes that from an accident.
    vendored-mkderivation-neutral =
      let
        probe =
          stdenv:
          (stdenv.mkDerivation (finalAttrs: {
            pname = "mkderivation-probe";
            version = "1";
            src = null;
            dontUnpack = true;
            configureFlags = [ "--probe" ];
            buildInputs = [ pkgs.zlib ];
            nativeBuildInputs = [ pkgs.pkg-config ];
            hardeningDisable = [ "format" ];
            enableParallelBuilding = true;
            installPhase = "mkdir -p $out";
          })).drvPath;
        tvp = probe bases.default.stdenv;
        upstream = probe pkgs.stdenv;
      in
      if tvp == upstream then
        pkgs.runCommand "tvp-check-mkderivation-neutral" { inherit tvp; } ''
          printf '%s\n' "$tvp" > "$out"
        ''
      else
        throw "TVP: vendored mkDerivation is no longer derivation-neutral:\n  nixpkgs ${upstream}\n  tvp     ${tvp}";

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
      inherit packages bases;
      inherit tvpLib;
    };
  };

  tvp = {
    inherit
      bases
      packages
      checks
      testBatches
      tools
      ;
    lib = tvpLib;
  };
in
tvp
