{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  candidate = import ../../../bases/source-gnu { };
  owned = {
    constructor = tvp.builder;
    builder = ./build-1.4.1.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/mpc/mpc-${version}.tar.xz";
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
      mpfr = tvp.packages.mpfr_4;
    };
  };
  defs = tvpLib.packages.mkDefs {
    "1.0.3" = {
      builder = ./build-1.0.3.nix;
      base = tvp.bases.default;
      deps = {
        gmp = tvp.packages.gmp_6;
        mpfr = tvp.lib.packages.withConstraint {
          reason = "MPC 1.0.3 mul.c defines its own seven-argument mpfr_fmma; MPFR 4 adds a six-argument public function with that name. Native compilation fails with 4.2.2; use the working MPFR 3 line.";
        } tvp.packages.mpfr_3;
      };
    };
    "1.1.0" = {
      builder = ./build-1.0.3.nix;
      base = tvp.bases.default;
      deps = {
        gmp = tvp.packages.gmp_6;
        mpfr = tvp.packages.mpfr_4;
      };
    };
    "1.4.0" = {
      builder = ./build-1.0.3.nix;
      base = tvp.bases.default;
      deps = {
        gmp = tvp.packages.gmp_6;
        mpfr = tvp.packages.mpfr_4;
      };
      opts.archiveExt = "tar.xz";
    };
    "1.4.1" =
      if native then
        owned
      else
        {
          constructor = tvp.builder;
          builder = ./build-steps-1.4.1.nix;
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
            mpfr = tvp.packages.mpfr_4;
            python = tvp.packages.python_3;
            binutils = tvp.packages.binutils_2;
            patchelf = tvp.packages.patchelf_0;
          };
        };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.0.3";
      releases = {
        "1.0.3" = "sha256-YX3sxuoJiJ+wjt4zCRegCxaAm424jCnDG/u0nL+I7MM=";
      };
    }
    {
      def = defs."1.1.0";
      releases = {
        "1.1.0" = "sha256-aYXFOBQ8EgjcsaxCztrW/1LiZ7R+X5cBg6PnUSW0PC4=";
        "1.2.0" = "sha256-6Q8tmVU6nBmRGr20MFv4IXEGqVfjmUQ2QoVyyN/o/aY=";
        "1.2.1" = "sha256-F1A9LDld/PEGtiLcFCaDwRmUMdCVNnxqrLpu7DA0BFk=";
        "1.3.0" = "sha256-DjsSGB03IHIw9aen3c/CKr/F/JwFgl4aZUAaSJpDKio=";
        "1.3.1" = "sha256-q2QkkvXPiCt0qgy3MM1BCoHtzb7IlRg86TDnBsHHWbg=";
      };
    }
    {
      def = defs."1.4.0";
      releases = {
        "1.4.0" = "sha256-MhCzpUaxywDClso2CJHXdA7m/wbesCono1sgzTwLsaU=";
      };
    }
    {
      def = defs."1.4.1";
      releases."1.4.1" = "sha256-kSBM0y8WS9O3yZLUpqjOZRlRGq2rMPeLaYLQv41z6TE=";
    }
  ];
  source =
    { version, sha256 }:
    pkgs.fetchurl {
      url = "https://mirrors.kernel.org/gnu/mpc/mpc-${version}.tar.xz";
      inherit sha256;
    };
  pname = "mpc";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      mpc:
      import ./tests {
        inherit tvpLib mpc;
        pkgs =
          if mpc ? testContext then
            pkgs
          else
            tvpLib.tests.withBase {
              inherit pkgs;
              base.stdenv = mpc.stdenv;
            };
      }
    ) { inherit pkgs; };
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://mirrors.kernel.org/gnu/mpc/";
      pattern = "mpc-[0-9][^\"]*\\.tar\\.(gz|xz)";
      normalise =
        file:
        let
          match = builtins.match "mpc-([0-9]+(\\.[0-9]+)*)\\.tar\\.(gz|xz)" file;
        in
        if match == null then null else builtins.head match;
      include = version: builtins.match "[0-9]+(\\.[0-9]+)*" version != null;
    };
  };
  ordinaryDefs = tvpLib.packages.mkDefs {
    "1.1.0" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-1.1.0.nix;
      base = candidate.base;
      helpers = {
        inherit tvp;
      };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://mirrors.kernel.org/gnu/mpc/mpc-${version}.tar.gz";
          inherit sha256;
        };
      deps = {
        bash = candidate.tools.bash;
        coreutils = candidate.tools.coreutils;
        gnumake = candidate.tools.make;
        gnutar = candidate.tools.tar;
        python = candidate.tools.python;
        binutils = candidate.tools.binutils;
        patchelf = candidate.tools.patchelf;
        sed = candidate.tools.sed;
        grep = candidate.tools.grep;
        gawk = candidate.tools.gawk;
        diffutils = candidate.tools.diffutils;
        findutils = candidate.tools.findutils;
        gzip = candidate.tools.gzip;
        gmp = tvp.packages.gmp_6;
        mpfr = tvp.packages.mpfr_4;
      };
    };
    "1.2.0" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-1.2.0.nix;
      base = candidate.base;
      helpers = {
        inherit tvp;
      };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://mirrors.kernel.org/gnu/mpc/mpc-${version}.tar.gz";
          inherit sha256;
        };
      deps = {
        bash = candidate.tools.bash;
        coreutils = candidate.tools.coreutils;
        gnumake = candidate.tools.make;
        gnutar = candidate.tools.tar;
        python = candidate.tools.python;
        binutils = candidate.tools.binutils;
        patchelf = candidate.tools.patchelf;
        sed = candidate.tools.sed;
        grep = candidate.tools.grep;
        gawk = candidate.tools.gawk;
        diffutils = candidate.tools.diffutils;
        findutils = candidate.tools.findutils;
        gzip = candidate.tools.gzip;
        gmp = tvp.packages.gmp_6;
        mpfr = tvp.packages.mpfr_4;
      };
    };
    "1.4.0" = {
      constructor = tvp.builder;
      builder = ./ordinary/build-1.4.0.nix;
      base = candidate.base;
      helpers = {
        inherit tvp;
      };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://mirrors.kernel.org/gnu/mpc/mpc-${version}.tar.xz";
          inherit sha256;
        };
      deps = {
        bash = candidate.tools.bash;
        coreutils = candidate.tools.coreutils;
        gnumake = candidate.tools.make;
        gnutar = candidate.tools.tar;
        xz = candidate.tools.xz;
        python = candidate.tools.python;
        binutils = candidate.tools.binutils;
        patchelf = candidate.tools.patchelf;
        sed = candidate.tools.sed;
        grep = candidate.tools.grep;
        gawk = candidate.tools.gawk;
        diffutils = candidate.tools.diffutils;
        findutils = candidate.tools.findutils;
        gmp = tvp.packages.gmp_6;
        mpfr = tvp.packages.mpfr_4;
      };
    };
  };
  ordinaryTable = versionTable // {
    "1.1.0" = versionTable."1.1.0" // {
      def = if native then ordinaryDefs."1.1.0" else versionTable."1.1.0".def;
    };
    "1.2.0" = versionTable."1.2.0" // {
      def = if native then ordinaryDefs."1.2.0" else versionTable."1.2.0".def;
    };
    "1.2.1" = versionTable."1.2.1" // {
      def = if native then ordinaryDefs."1.2.0" else versionTable."1.2.1".def;
    };
    "1.3.0" = versionTable."1.3.0" // {
      def = if native then ordinaryDefs."1.2.0" else versionTable."1.3.0".def;
    };
    "1.3.1" = versionTable."1.3.1" // {
      def = if native then ordinaryDefs."1.2.0" else versionTable."1.3.1".def;
    };
    "1.4.0" = versionTable."1.4.0" // {
      def = if native then ordinaryDefs."1.4.0" else versionTable."1.4.0".def;
    };
  };
  previousPublicArgs = packageArgs // {
    versionTable = ordinaryTable;
    inherit source;
  };
  # Retain the complete historical construction, including its original test factory.
  # Preserve the complete old arithmetic factory before public dependency promotion.
  retainedDependencyRecipe = (import ../mpfr { inherit pkgs tvp; }).recipes.mpfr.constructionRecipe;
  retainedDependency = (tvpLib.packages.mkVersions retainedDependencyRecipe).mpfr_3_1_6;
  constructionRecipe = packageArgs // {
    versionTable = versionTable // {
      "1.0.3" = versionTable."1.0.3" // {
        def = defs."1.0.3" // { deps = defs."1.0.3".deps // {
          mpfr = tvpLib.packages.tagSelection defs."1.0.3".deps.mpfr.__tvpSelection retainedDependency;
        }; };
      };
      "1.4.1" = versionTable."1.4.1" // {
        def = defs."1.4.0";
      };
    };
  };
  compatibilityDefs = import ./compatibility { inherit tvp tvpLib candidate defs; };
  compatibilityVersions = [ "1.0.3" ];
  publicArgs = previousPublicArgs // {
    versionTable = previousPublicArgs.versionTable // builtins.listToAttrs (map (version: {
      name = version;
      value = versionTable.${version} // { def = if native then compatibilityDefs.${version} else versionTable.${version}.def; };
    }) compatibilityVersions);
    extraArgs = previousPublicArgs.extraArgs // {
      mkTests = package:
        if package ? testContext && builtins.elem package.version compatibilityVersions then
          packageArgs.extraArgs.mkTests package
          // pkgs.lib.optionalAttrs (package.specification.upstreamCheck.enabled or true) {
            upstream = import ../acl/native/upstream.nix { inherit package; };
          }
          else previousPublicArgs.extraArgs.mkTests package;
    };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;

in
{
  recipes.${pname} = publicArgs // {
    inherit constructionRecipe;
  };
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
