{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  candidate = import ../../../bases/source-gnu { };
  defs = tvpLib.packages.mkDefs {
    "4.4.36" = {
      builder = ./build-4.4.36.nix;
      base = tvp.bases.default;
      deps.perl = tvp.packages.perl_5;
      # ascii64 retains its explicit NUL and discards a redundant implicit NUL.
      # GCC15 adds this Wextra diagnostic; keep it visible and all other Werror.
      opts.compileFlags = [ "-Wno-error=unterminated-string-initialization" ];
    };
    "4.5.0" = {
      builder = ./build-4.4.36.nix;
      base = tvp.bases.default;
      deps.perl = tvp.packages.perl_5;
    };

  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."4.4.36";
      releases = {
        "4.4.36" = "sha256-5eH0yu4KAd4q7ibjE4gH1tPKK45nKHlm0f79ZeH9iUM=";

      };
    }
    {
      def = defs."4.5.0";
      releases = {
        "4.5.0" = "sha256-gl52Tk/y5jBK24FM2ilwdLIi1UoE7b2OvHz1j8OvhX0=";
        "4.5.1" = "sha256-6bRqYjl8FTcpNfanXcOSnGIWHyYgvnt/V/A9aRAsGoY=";
        "4.5.2" = "sha256-cVE6McAaQovM1TZ6Mv2V8RXW2sUPtbYMd51ceUKuwHE=";
      };
    }
  ];
  pname = "libxcrypt";
  testDeps.pkg-config = tvp.packages.pkg-config;
  testDeps.gnused = tvp.packages.gnused;
  testDeps.coreutils = tvp.packages.coreutils;
  # Keep the original default-base constructor as the ABI control. Its lazy
  # tests close over this same retained control, never the ordinary canonical
  # 4.4.36 route. Frozen GCC13/GCC16 suites inherit this exact producer.
  testDeps.baseline = tvp.lib.packages.withConstraint {
    category = "artifact";
    reason = "Historical libxcrypt 4.4.36 crypt-format compatibility baseline; newer releases are compared against this exact release.";
  } ((tvpLib.packages.mkVersions packageArgs).libxcrypt_4_4_36);
  packageArgs = {
    inherit testDeps;
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests =
      package:
      import ./tests {
        inherit pkgs tvpLib package;
        pkg-config = package.tvp.declaredTestDependencies.pkg-config;
        inherit (package.tvp.declaredTestDependencies) baseline gnused coreutils;
      };
    packageMeta.upstream = {
      type = "git-tags";
      url = "https://github.com/besser82/libxcrypt";
      normalise =
        tag:
        let
          matched = builtins.match "v([0-9]+\\.[0-9]+\\.[0-9]+)" tag;
        in
        if matched == null then null else builtins.head matched;
    };
  };
  completed = tvp.bases.default;
  seed =
    reason:
    tvpLib.packages.withConstraint {
      category = "construction";
      inherit reason;
    };
  legacy =
    (tvpLib.packages.mkDefs {
      "4.5.2" = {
        constructor = tvp.builder;
        builder = ./build-4.5.2.nix;
        base = completed;
        helpers = {
          inherit tvp;
        };
        deps = {
          bash = tvp.packages.bash_5;
          gnumake = tvp.packages.gnumake_4;
          perl = tvp.packages.perl_5;
          coreutils = seed "Completed floor Coreutils breaks the canonical Coreutils/libxcrypt prerequisite cycle during library construction." completed.components.floor.coreutils;
          gnutar = seed "Completed floor Tar unpacks libxcrypt without following Tar's ACL/Attr prerequisites." completed.components.floor.gnutar;
          xz = seed "Completed floor XZ unpacks the selected libxcrypt source without rebuilding its canonical archive graph." completed.components.floor.xz;
          gzip = seed "Completed floor Gzip compresses installed manuals without introducing a canonical archive cycle." completed.components.floor.gzip;
          python = seed "Completed libc helper Python performs build-only explicit source and output operations." completed.components.libc.tvp.deps.python3Minimal;
          binutils = seed "Completed base Binutils performs build-only output inspection and stripping." completed.components.binutils;
          patchelf = seed "Completed base Patchelf performs build-only ELF finalization without following the canonical archive graph." completed.fixupTools.patchelf;
        };
      };
    })."4.5.2";
  constructionRecipe = packageArgs;
  ownedDefs = tvpLib.packages.mkDefs {
    "4.5.2" = {
      constructor = tvp.builder;
      builder = ./native/build-4.5.2.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://github.com/besser82/libxcrypt/releases/download/v${version}/libxcrypt-${version}.tar.xz";
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
      # Retained source-built host tools avoid Coreutils/Tar/Perl/archive cycles.
      deps = {
        inherit (candidate.tools)
          bash
          coreutils
          gzip
          python
          binutils
          patchelf
          sed
          grep
          gawk
          diffutils
          findutils
          perl
          xz
          ;
        gnumake = candidate.tools.make;
        gnutar = candidate.tools.tar;
      };
    };
  };
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} is a build-only host generation; ordinary Coreutils/Tar/Perl consume these target libraries.";
    } candidate.tools.${name};
  ordinaryDefs = import ./ordinary {
    inherit
      tvp
      tvpLib
      candidate
      constructionTool
      ;
  };
  publicArgs = packageArgs // {
    versionTable = versionTable // {
      "4.4.36" = versionTable."4.4.36" // {
        def = if native then ordinaryDefs."4.4.36" else versionTable."4.4.36".def;
      };
      "4.5.0" = versionTable."4.5.0" // {
        def = if native then ordinaryDefs."4.5.0" else versionTable."4.5.0".def;
      };
      "4.5.1" = versionTable."4.5.1" // {
        def = if native then ordinaryDefs."4.5.1" else versionTable."4.5.1".def;
      };

      "4.5.2" = versionTable."4.5.2" // {
        def = if native then ownedDefs."4.5.2" else legacy;
      };
    };
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        url = "https://github.com/besser82/libxcrypt/releases/download/v${version}/libxcrypt-${version}.tar.xz";
        inherit sha256;
      };
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      (
        (
          package:
          (import ./tests {
            inherit pkgs tvpLib package;
            pkg-config = package.tvp.declaredTestDependencies.pkg-config;
            inherit (package.tvp.declaredTestDependencies) baseline gnused coreutils;
          })
          // pkgs.lib.optionalAttrs (package.version == "4.5.2") (
            import ./tests/owned.nix {
              inherit tvp tvpLib package;
              pkgs =
                if package ? testContext then
                  pkgs
                else
                  tvpLib.tests.withBase {
                    inherit pkgs;
                    base.stdenv = package.stdenv;
                  };
            }
          )
        )
        package
      )
      //
        pkgs.lib.optionalAttrs
          (
            package ? testContext
            && builtins.elem package.version [
              "4.4.36"
              "4.5.0"
              "4.5.1"
            ]
          )
          (
            import ./tests/ordinary.nix {
              inherit
                pkgs
                tvpLib
                package
                tvp
                ;
            }
          )
    ) { inherit pkgs; };
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
