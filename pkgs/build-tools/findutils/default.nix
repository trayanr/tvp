{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "4.10.0" = {
      builder = ./build-4.10.0.nix;
      base = tvp.bases.default;
      deps = {
        coreutils = tvp.packages.coreutils;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."4.10.0";
      releases."4.10.0" = "sha256-E4fgtn/yR9Kr3pmPkN+/cMFJE5Glnd/suK5ph4nwpPU=";
      releases."4.11.0" = "sha256-v9GcsGzHHzNS1WfpAoTYzawCrIl3S76t8LUzsMEUMv0=";
    }
  ];
  pname = "findutils";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = package: import ./tests { inherit pkgs tvpLib package; };
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://mirrors.kernel.org/gnu/findutils/";
      pattern = "findutils-[0-9][^\"]*\\.tar\\.(gz|bz2|xz|lz)";
      # Multiple archive formats describe the same numeric release. The
      # directory-index adapter deduplicates the normalised versions.
      normalise =
        file:
        let
          matched = builtins.match "findutils-([0-9]+(\\.[0-9]+)+)\\.tar\\.(gz|bz2|xz|lz)" file;
        in
        if matched == null then null else builtins.head matched;
      include = version: builtins.match "[0-9]+(\\.[0-9]+)+" version != null;
    };
  };
  # Complete capture, including the old table and test/source factories.
  constructionRecipe = packageArgs;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  constructionTool =
    name:
    tvpLib.packages.withConstraint {
      category = "construction";
      reason = "Retained source-GNU ${name} is a build-only host generation; ordinary Coreutils/Tar consume the target libraries used to construct these tools.";
    } candidate.tools.${name};
  ownedDefs = tvpLib.packages.mkDefs {
    "4.11.0" = {
      constructor = tvp.builder;
      builder = ./native/build-4.11.0.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://mirrors.kernel.org/gnu/findutils/findutils-${version}.tar.xz";
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
        bash = constructionTool "bash";
        buildCoreutils = constructionTool "coreutils";
        gnumake = constructionTool "make";
        gnutar = constructionTool "tar";
        xz = constructionTool "xz";
        gzip = constructionTool "gzip";
        python = constructionTool "python";
        perl = constructionTool "perl";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
        sed = constructionTool "sed";
        grep = constructionTool "grep";
        gawk = constructionTool "gawk";
        diffutils = constructionTool "diffutils";
        findutils = constructionTool "findutils";
        coreutils = tvp.packages.coreutils;
      };
    };
  };
  locale = import ../../../lib/tests/gnu-locale.nix {
    builder = tvp.builder;
    base = candidate.base;
    inherit (candidate.tools)
      bash
      coreutils
      tar
      xz
      ;
    libc = candidate.toolchain.libc;
  };
  publicArgs = packageArgs // {
    extraArgs.mkTests =
      package:
      (
        if package ? testContext then
          import ./tests/native-default.nix {
            inherit
              pkgs
              tvpLib
              package
              locale
              ;
          }
        else
          packageArgs.extraArgs.mkTests package
      )
      // pkgs.lib.optionalAttrs (package ? testContext) (
        import ../../../lib/tests/command-source-edit.nix { inherit tvp package; }
      )
      // pkgs.lib.optionalAttrs (package ? testContext) (
        import ../../../lib/tests/command-helper.nix {
          inherit tvp package;
          helperName = "sort";
          invocation = q: ''
            mkdir tree
            touch tree/marker
            ${q}/bin/updatedb --localpaths="$PWD/tree" --prunepaths="" --netpaths="" --output=locate.db
            ${q}/bin/locate -d locate.db marker | grep -F /tree/marker >&2
          '';
        }
      );
    versionTable = versionTable // {
      "4.11.0" = versionTable."4.11.0" // {
        def = if native then ownedDefs."4.11.0" else versionTable."4.11.0".def;
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
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
