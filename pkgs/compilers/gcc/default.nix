{ tvp, ... }:
let
  # This named tier is the closed source-full-GCC driver, not canonical GCC.
  compilerHostBase = tvp.bases.gcc_16.full;
  reference = import ../../../bootstrap/source-full-gcc.nix { };
  # MIG-002 remains open: retain the current production interpreter/profile.
  productionPython = tvp.lib.packages.withConstraint {
    category = "construction";
    reason = "Captured public GCC production Python profile; requirements must be established before replacing it with the raw interpreter.";
  } reference.harness.previous.profile;
  preparationPerl = tvp.lib.packages.withConstraint {
    category = "construction";
    reason = "Exact preceding-generation Perl used by the compiler source procedure and libgomp helper preparation.";
  } reference.prerequisites.perl;
  documentationTexinfo = tvp.lib.packages.withConstraint {
    category = "construction";
    reason = "Exact preceding-generation Texinfo for GCC production documentation; do not activate a public compiler through its tools.";
  } reference.prerequisites.texinfo;
  pname = "gcc";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-owned-13.3.0.nix;
        base = compilerHostBase;
        deps = {
          binutils = tvp.packages.binutils_2;
          gmp = tvp.packages.gmp_6;
          mpfr = tvp.packages.mpfr_4;
          mpc = tvp.packages.mpc_1;
          isl = tvp.packages.isl;
          zlib = tvp.packages.zlib_1;
          zstd = tvp.packages.zstd_1;
          libxcrypt = tvp.packages.libxcrypt_4;
          perl = preparationPerl;
          texinfo = documentationTexinfo;
          which = tvp.packages.which;
          python = productionPython;
          # Existing configure-visible File/libmagic stays in A (MIG-003).
          inherit (reference) file;
          # Captured harness roles stay lazy and outside production commands.
          inherit (reference.harness.previous.harness) dejagnu expect flock;
          pythonConfig = reference.harness.tools.python;
          graphviz = reference.harness.packages.graphviz;
          fonts = reference.harness.fonts;
          glibc = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Completed default base target libc; moving public glibc consumes this raw compiler and would introduce a cycle.";
          } compilerHostBase.compiler.libc;
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
      releases."13.3.0" = "sha256-CEXpYhyVQ6E/SE6UWEpJ/8ASmXDpkUYkI1/B0GGgwIM=";
    }
    {
      def = {
        builder = ./build-owned-16.2.0.nix;
        base = compilerHostBase;
        deps = {
          binutils = tvp.packages.binutils_2;
          gmp = tvp.packages.gmp_6;
          mpfr = tvp.packages.mpfr_4;
          mpc = tvp.packages.mpc_1;
          isl = tvp.packages.isl;
          zlib = tvp.packages.zlib_1;
          zstd = tvp.packages.zstd_1;
          libxcrypt = tvp.packages.libxcrypt_4;
          perl = preparationPerl;
          texinfo = documentationTexinfo;
          which = tvp.packages.which;
          python = productionPython;
          # Existing configure-visible File/libmagic stays in A (MIG-003).
          inherit (reference) file;
          # Captured harness roles stay lazy and outside production commands.
          inherit (reference.harness.previous.harness) dejagnu expect flock;
          pythonConfig = reference.harness.tools.python;
          graphviz = reference.harness.packages.graphviz;
          fonts = reference.harness.fonts;
          glibc = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Explicit candidate target libc; moving public glibc consumes this raw compiler and would introduce a cycle.";
          } compilerHostBase.compiler.libc;
          layoutPatch = reference.native.sources.layout;
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
      releases."16.2.0" = "sha256-5nOOKVl/czJwcxqpBgDzf/3ARQed/CfsfoGSzIEIXD4=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
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
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://mirrors.kernel.org/gnu/gcc/gcc-${version}/gcc-${version}.tar.xz";
        inherit sha256;
      };
    tests = import ./tests/installed.nix;
    testDeps.python3 = tvp.packages.python_3;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.gcc = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
