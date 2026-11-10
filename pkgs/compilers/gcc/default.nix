{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "13.3.0" = {
      builder = ./build-13.3.nix;
      base = tvp.bases.default;
      # Upstream libcpp uses nonliteral diagnostics with no format arguments.
      opts.hardeningDisable = [ "format" ];
      deps = {
        binutils = tvp.packages.binutils_2;
        gmp = tvp.packages.gmp_6;
        mpfr = tvp.packages.mpfr_4;
        mpc = tvp.packages.mpc_1;
        isl = tvp.packages.isl;
        zlib = tvp.packages.zlib_1;
        zstd = tvp.packages.zstd_1;
        libxcrypt = tvp.packages.libxcrypt_4;
        perl = tvp.packages.perl_5;
        texinfo = tvp.packages.texinfo;
        which = tvp.packages.which;
        # The native target runtime belongs to the completed base composition.
        glibc = tvp.lib.packages.withConstraint {
          category = "construction";
          reason = "Reuse the completed default base's pinned native target libc. The standalone canonical glibc package is rebuilt independently; moving it must not move this compiler's explicit base/runtime composition.";
        } tvp.bases.default.stdenv.cc.libc;
      };
      patches = [
        {
          file = ./patches/program-prefix.patch;
          reason = "Store-layout adaptation: let GCC's explicit -B prefixes select the assembler and program queries before the configured absolute fallback. This makes the base's selected binutils real, rather than silently using the compiler's bootstrap assembler.";
        }
        {
          file = ./patches/linker-prefix.patch;
          reason = "Store-layout adaptation: let collect2 find the linker from GCC's explicit -B/COMPILER_PATH before the configured absolute fallback, so a base can select its libc/linker wrapper. Without this, -print-prog-name=ld reports the wrapper but collect2 invokes the raw linker.";
        }
        {
          file = ./patches/no-system-dirs.patch;
          reason = "Store-layout adaptation: remove implicit /usr/local/include, /lib and /usr/lib searches. Headers and startup objects are named by the toolchain. From nixpkgs 12228ff1752d7b7624a54e9c1af4b222b3c1073b, gcc-12-no-sys-dirs.patch.";
        }
      ];
    };
    "16.2.0" = {
      builder = ./build-16.2.0.nix;
      base = tvp.bases.default;
      # Upstream libcpp uses nonliteral diagnostics with no format arguments.
      opts.hardeningDisable = [ "format" ];
      # External dependencies meet upstream configure requirements. ISL 0.28
      # is newer than the in-tree 0.24 recommendation; Graphite is tested.
      deps = {
        binutils = tvp.packages.binutils_2;
        gmp = tvp.packages.gmp_6;
        mpfr = tvp.packages.mpfr_4;
        mpc = tvp.packages.mpc_1;
        isl = tvp.packages.isl;
        zlib = tvp.packages.zlib_1;
        zstd = tvp.packages.zstd_1;
        libxcrypt = tvp.packages.libxcrypt_4;
        perl = tvp.packages.perl_5;
        texinfo = tvp.packages.texinfo;
        which = tvp.packages.which;
        # Canonical GCC follows the default; the constructor pins a separate variant.
        glibc = tvp.lib.packages.withConstraint {
          category = "construction";
          reason = "The bootstrap compiler and native target use the completed default base's pinned libc. Canonical glibc is built by this compiler, so selecting it here would also form a cycle. The separately pinned constructor never follows ordinary dependency aliases.";
        } tvp.bases.default.stdenv.cc.libc;
      };
      patches = [
        {
          file = ./patches/16.2.0-program-prefix.patch;
          reason = "Store-layout adaptation: let GCC's explicit -B prefixes select the assembler and program queries before the configured absolute fallback. This makes the base's selected binutils real, rather than silently using the compiler's bootstrap assembler.";
        }
        {
          file = ./patches/16.2.0-linker-prefix.patch;
          reason = "Store-layout adaptation: let collect2 find the linker from GCC's explicit -B/COMPILER_PATH before the configured absolute fallback, so a base can select its libc/linker wrapper. Without this, -print-prog-name=ld reports the wrapper but collect2 invokes the raw linker.";
        }
        {
          file = ./patches/no-system-dirs.patch;
          reason = "Store-layout adaptation: remove implicit /usr/local/include, /lib and /usr/lib searches. Headers and startup objects are named by the toolchain. From nixpkgs 12228ff1752d7b7624a54e9c1af4b222b3c1073b, gcc-12-no-sys-dirs.patch.";
        }
      ];
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."13.3.0";
      releases."13.3.0" = "sha256-CEXpYhyVQ6E/SE6UWEpJ/8ASmXDpkUYkI1/B0GGgwIM=";
    }
    {
      def = defs."16.2.0";
      releases."16.2.0" = "sha256-5nOOKVl/czJwcxqpBgDzf/3ARQed/CfsfoGSzIEIXD4=";
    }
  ];
  pname = "gcc";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl dejagnu;
      python3 = pkgs.python3.withPackages (ps: [
        ps.pytest
        ps.jsonschema
      ]);
      # OpenMP parallel execution needs the real native flock helper.
      flock = pkgs.util-linux;
      # HTML diagnostic CFG tests invoke dot to generate their SVG.
      graphviz = pkgs.graphviz;
      fontsConf = pkgs.makeFontsConf { fontDirectories = [ pkgs.dejavu_fonts ]; };
      inherit (tvpLib) platforms;
    };
    inherit pname versionTable;
    testDeps.python3 = tvp.packages.python_3;
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://gcc.gnu.org/pub/gcc/releases/";
      # Keep complete links so snapshots, prereleases and suffix junk cannot
      # contribute a numeric release substring.
      pattern = "href=\"[^\"]*\"";
      normalise =
        href:
        let
          match = builtins.match ''href="gcc-([0-9]+(\.[0-9]+)+)/"'' href;
        in
        if match == null then null else builtins.head match;
    };
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      gcc:
      (import ./tests { inherit pkgs tvpLib gcc; })
      // pkgs.lib.optionalAttrs (pkgs.lib.versionAtLeast gcc.version "16.2.0") (
        import ./tests/16.2.0.nix {
          inherit pkgs tvpLib gcc;
          inherit (gcc.tvp.declaredTestDependencies) python3;
        }
      )
    ) { inherit pkgs; };
  };
  constructionRecipe = packageArgs;
  candidate = import ../../../bases/source-gnu { };
  reference = import ../../../bootstrap/source-full-gcc.nix { };
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} supplies the independent host generation; public GCC never constructs itself.";
    } candidate.tools.${name};
  ownedDefs = tvpLib.packages.mkDefs {
    "16.2.0" = {
      constructor = tvp.builder;
      builder = ./native/build-16.2.0.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://mirrors.kernel.org/gnu/gcc/gcc-${version}/gcc-${version}.tar.xz";
          inherit sha256;
        };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      deps = {
        bash = constructionTool "bash";
        coreutils = constructionTool "coreutils";
        gnumake = constructionTool "make";
        gnutar = constructionTool "tar";
        xz = constructionTool "xz";
        gzip = constructionTool "gzip";
        patch = constructionTool "patch";
        findutils = constructionTool "findutils";
        sed = constructionTool "sed";
        grep = constructionTool "grep";
        gawk = constructionTool "gawk";
        diffutils = constructionTool "diffutils";
        perl = constructionTool "perl";
        texinfo = constructionTool "texinfo";
        which = tvp.packages.which;
        binutils = tvp.packages.binutils_2;
        gmp = tvp.packages.gmp_6;
        mpfr = tvp.packages.mpfr_4;
        mpc = tvp.packages.mpc_1;
        isl = tvp.packages.isl;
        zlib = tvp.packages.zlib_1;
        zstd = tvp.packages.zstd_1;
        libxcrypt = tvp.packages.libxcrypt_4;
        glibc = tvpLib.packages.withConstraint {
          category = "construction";
          reason = "Explicit candidate target libc; moving public glibc consumes this raw compiler and would introduce a cycle.";
        } candidate.toolchain.libc;
        layoutPatch = reference.native.sources.layout;
        inherit (reference.harness.previous.harness) dejagnu expect flock;
        python = reference.harness.previous.profile;
        pythonConfig = reference.harness.tools.python;
        graphviz = reference.harness.packages.graphviz;
        fonts = reference.harness.fonts;
        inherit (reference) file;
      };
      patches = [
        {
          file = ./patches/16.2.0-full-libgcc-copyback.patch;
          reason = "Retain in-tree libgcc copyback after the native layout patch renames libsubdir.";
        }
        {
          file = ./patches/no-system-dirs.patch;
          reason = "Remove implicit host include and library searches; libc construction supplies its own flags.";
        }
        {
          file = ./patches/16.2.0-program-prefix.patch;
          reason = "Honor explicit assembler and program -B prefixes before configured fallbacks.";
        }
        {
          file = ./patches/16.2.0-linker-prefix.patch;
          reason = "Honor explicit collect2 linker -B prefixes before configured fallbacks.";
        }
      ];
    };
  };
  publicArgs = packageArgs // {
    versionTable = versionTable // {
      "16.2.0" = versionTable."16.2.0" // {
        def =
          if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then
            ownedDefs."16.2.0"
          else
            versionTable."16.2.0".def;
      };
    };
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        import ./tests/native-16.2.0.nix { inherit package; }
      else
        (constructionRecipe.extraArgs.mkTests.override { inherit pkgs; }) package
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
