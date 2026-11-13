# Preserve the optional build-steps control, independently of public definitions.
{
  pkgs,
  tvp,
  family,
}:
pkgs.lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
  mpfr_4_2_2 = tvp.builder {
    recipe = import ./build-steps-4.2.2.nix;
    args =
      {
        inherit tvp;
        inherit (pkgs) lib;
        base = tvp.bases.default;
        version = "4.2.2";
        src = family.source {
          version = "4.2.2";
          inherit (family.versionTable."4.2.2") sha256;
        };
        inherit (tvp.packages)
          bash
          coreutils
          gnumake
          gnutar
          xz
          ;
      }
      // {
        gmp = tvp.packages.gmp_6;
        python = tvp.packages.python_3;
        binutils = tvp.packages.binutils_2;
        patchelf = tvp.packages.patchelf_0;
      };
    dependencyNames = [
      "python"
      "binutils"
      "patchelf"
      "gmp"
      "bash"
      "coreutils"
      "gnumake"
      "gnutar"
      "xz"
    ];
    infrastructure = family.infra;
    metadata = family.packageMeta // {
      status.level = "ok";
      canonical = false;
      variant = "build-steps";
      builder = "build-steps-4.2.2.nix";
      definition = "4.2.2";
      declaredTestDependencies = {
        python = tvp.packages.python_3;
      };
    };
    selection = {
      namespace = "variants.build-steps";
      selector = "mpfr_4_2_2";
      kind = "variant";
      pname = "mpfr";
      version = "4.2.2";
      canonical = "mpfr_4_2_2";
    };
    mkTests =
      package:
      family.extraArgs.mkTests package
      // {
        runtime-expectation = import ../../../lib/runtime-expectation.nix { inherit (pkgs) lib; } {
          inherit package;
          stdenv = package.stdenv;
          python = tvp.packages.python_3;
        };
      };
  };
}
