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
        binutils = tvp.packages.binutils_2_42;
        gmp = tvp.packages.gmp_6_3_0;
        mpfr = tvp.packages.mpfr_4_2_1;
        mpc = tvp.packages.mpc_1_3_1;
        isl = tvp.packages.isl_0_20;
        zlib = tvp.packages.zlib_1_3_2;
        zstd = tvp.packages.zstd_1_5_6;
        libxcrypt = tvp.packages.libxcrypt_4_4_36;
        perl = tvp.packages.perl_5_44_0;
        texinfo = tvp.packages.texinfo_7_1;
        which = tvp.packages.which_2_21;
        # Use the base libc; canonical glibc itself is built with this compiler.
        glibc = tvp.bases.default.stdenv.cc.libc;
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
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."13.3.0";
      releases."13.3.0" = "sha256-CEXpYhyVQ6E/SE6UWEpJ/8ASmXDpkUYkI1/B0GGgwIM=";
    }
  ];
  pname = "gcc";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
      inherit (tvpLib) platforms;
    };
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
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }: gcc: import ./tests { inherit pkgs tvpLib gcc; }
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions packageArgs;

in
{
  recipes.${pname} = packageArgs;
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
