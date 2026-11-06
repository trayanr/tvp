{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  candidate = import ../../../bases/source-gnu { };
  owned = {
    constructor = tvp.builder;
    builder = ./build-4.2.2.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/mpfr/mpfr-${version}.tar.xz";
        inherit sha256;
      };
    testContext =
      package:
      tvpLib.tests.fromPackage {
        builder = tvp.builder;
        inherit package;
      };
    helpers = {
      inherit tvp;
    };
    deps = {
      inherit (candidate.tools)
        bash
        coreutils
        xz
        python
        binutils
        patchelf
        sed
        grep
        gawk
        diffutils
        findutils
        ;
      gnumake = candidate.tools.make;
      gnutar = candidate.tools.tar;
      gmp = tvp.packages.gmp_6;
    };
  };
  defs = tvpLib.packages.mkDefs {
    "2.4.2" = {
      builder = ./build-2.4.2.nix;
      # trint.c's unprototyped callback requires C99-or-newer, pre-C23
      # semantics. 4.2.1's ChangeLog records its typed C2x-compatible fix.
      opts.checkCFlags = [ "-std=gnu17" ];
      base = tvp.bases.default;
      deps.gmp = tvp.lib.packages.withConstraint {
        reason = "MPFR 2.4.2/3.0.1 public headers use __gmp_const, removed by GMP 5.1. Native compilation fails with newer GMP; 5.0.5 is the working control, selected through the moving 5.0 line.";
      } tvp.packages.gmp_5_0;
      opts.float128 = false;
      opts.mpfrRoundingNames = false;
    };
    "3.0.1" = {
      builder = ./build-2.4.2.nix;
      # trint.c's unprototyped callback requires C99-or-newer, pre-C23
      # semantics. 4.2.1's ChangeLog records its typed C2x-compatible fix.
      opts.checkCFlags = [ "-std=gnu17" ];
      base = tvp.bases.default;
      deps.gmp = tvp.lib.packages.withConstraint {
        reason = "MPFR 2.4.2/3.0.1 public headers use __gmp_const, removed by GMP 5.1. Native compilation fails with newer GMP; 5.0.5 is the working control, selected through the moving 5.0 line.";
      } tvp.packages.gmp_5_0;
      opts.float128 = false;
    };
    "3.1.6" = {
      builder = ./build-2.4.2.nix;
      # trint.c's unprototyped callback requires C99-or-newer, pre-C23
      # semantics. 4.2.1's ChangeLog records its typed C2x-compatible fix.
      opts.checkCFlags = [ "-std=gnu17" ];
      base = tvp.bases.default;
      deps.gmp = tvp.packages.gmp_6;
      opts.float128 = false;
    };
    "4.0.2" = {
      builder = ./build-2.4.2.nix;
      # trint.c's unprototyped callback requires C99-or-newer, pre-C23
      # semantics. 4.2.1's ChangeLog records its typed C2x-compatible fix.
      opts.checkCFlags = [ "-std=gnu17" ];
      base = tvp.bases.default;
      deps.gmp = tvp.packages.gmp_6;
    };
    "4.2.1" = {
      builder = ./build-2.4.2.nix;
      base = tvp.bases.default;
      deps.gmp = tvp.packages.gmp_6;
    };

    "4.2.2" =
      if native then
        owned
      else
        {
          constructor = tvp.builder;
          builder = ./build-steps-4.2.2.nix;
          base = tvp.bases.default;
          helpers = {
            inherit tvp;
          };
          deps = {
            inherit (tvp.packages)
              bash
              coreutils
              gnumake
              gnutar
              xz
              ;
            gmp = tvp.packages.gmp_6;
            python = tvp.packages.python_3;
            binutils = tvp.packages.binutils_2;
            patchelf = tvp.packages.patchelf_0;
          };
        };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."2.4.2";
      releases = {
        "2.4.2" = "sha256-1ycbv7yd3zh9ORnfgxjNcZLGeyMpGb+hyzIC0HhD2hs=";
      };
    }
    {
      def = defs."3.0.1";
      releases = {
        "3.0.1" = "sha256-KKltWPJ2NSipebKgFpWdziq7yP74FC+hhgZwwkh2AGE=";
      };
    }
    {
      def = defs."3.1.6";
      releases = {
        "3.1.6" = "sha256-emKsGgRAhhT8zcUG5IRLEM8K0sKxZ3CX+PNdOhNEqVA=";
      };
    }
    {
      def = defs."4.0.2";
      releases = {
        "4.0.2" = "sha256-HTvnCGBOrg5C1Xi6k7OQwqFF8XdDp0TY8/jCrVhVo4o=";
        "4.1.0" = "sha256-DJij8XMv9spOppBVIHnanFl4ctMOluwoQU7iPJVVin8=";
        "4.1.1" = "sha256-/9GVvVZ9uv/DuYsj/QCq0FN2gMmJYXHkT+P/eeKKwz0=";
        "4.2.0" = "sha256-BqN43xNQEkjBsttaqXeiyBJq6Emp2be+JUb7Spwm2ZM=";
      };
    }
    {
      def = defs."4.2.1";
      releases = {
        "4.2.1" = "sha256-J3gHNTpnJpeJlpRa8T5Sgp46vXqaW3+yeTiU4Y8fy7I=";
      };
    }
    {
      def = defs."4.2.2";
      releases."4.2.2" = "sha256-tnugOD736KhWNzTi6InvXsPDuJigHQD6CmhprYHGzgE=";
    }
  ];
  source =
    { version, sha256 }:
    pkgs.fetchurl {
      url = "https://mirrors.kernel.org/gnu/mpfr/mpfr-${version}.tar.xz";
      inherit sha256;
    };
  pname = "mpfr";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      mpfr:
      import ./tests {
        inherit tvpLib mpfr;
        pkgs =
          if mpfr ? testContext then
            pkgs
          else
            tvpLib.tests.withBase {
              inherit pkgs;
              base.stdenv = mpfr.stdenv;
            };
      }
    ) { inherit pkgs; };
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://mirrors.kernel.org/gnu/mpfr/";
      pattern = "mpfr-[0-9][^\"]*\\.tar\\.(gz|bz2|xz)";
      normalise =
        file:
        let
          match = builtins.match "mpfr-([0-9]+(\\.[0-9]+)*)\\.tar\\.(gz|bz2|xz)" file;
        in
        if match == null then null else builtins.head match;
      include = version: builtins.match "[0-9]+(\\.[0-9]+)*" version != null;
    };
  };
  publicArgs = packageArgs // {
    inherit source;
  };
  # Capture the entire legacy call, including its definition, dependencies,
  # options, infrastructure and test factory. Frozen compilers select it explicitly.
  constructionRecipe = packageArgs // {
    versionTable = versionTable // {
      "4.2.2" = versionTable."4.2.2" // {
        def = defs."4.2.1";
      };
    };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;

in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  variants.build-steps = pkgs.lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
    mpfr_4_2_2 = tvp.builder {
      recipe = import ./build-steps-4.2.2.nix;
      args =
        {
          inherit tvp;
          inherit (pkgs) lib;
          base = tvp.bases.default;
          version = "4.2.2";
          src = source {
            version = "4.2.2";
            inherit (versionTable."4.2.2") sha256;
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
      infrastructure = packageArgs.infra;
      metadata = packageArgs.packageMeta // {
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
        packageArgs.extraArgs.mkTests package
        // {
          runtime-expectation = import ../../../lib/runtime-expectation.nix { inherit (pkgs) lib; } {
            inherit package;
            stdenv = package.stdenv;
            python = tvp.packages.python_3;
          };
        };
    };
  };
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
