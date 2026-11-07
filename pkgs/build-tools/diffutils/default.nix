{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "3.10" = {
      builder = ./build-3.10.nix;
      base = tvp.bases.default;
      deps = {
        coreutils = tvp.packages.coreutils;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."3.10";
      releases = {
        "3.10" = "sha256-kOXpPMck5OvhLt6A3xY0Bjx6hVaSaFkZv+YLVWyb0J4=";
        "3.11" = "sha256-pz7wX+N91YX32HBo5KBjl2BBn4EBOL11xh3aofniEx4=";
        "3.12" = "sha256-fIt/n8hgkUH96pzs6FJJ0whiQ5H/Yd7a9Sj8szdyff0=";
      };
    }
  ];
  pname = "diffutils";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = package: import ./tests { inherit pkgs tvpLib package; };
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://mirrors.kernel.org/gnu/diffutils/";
      # Capture whole filenames, including any README, signature or diff suffix.
      # Normalising a matched prefix would falsely count those as archives.
      pattern = ''[^"<>/[:space:]]+\.tar\.[^"<>/[:space:]]+'';
      normalise =
        file:
        let
          archive = builtins.match "diffutils-([0-9]+(\\.[0-9]+)*)\\.tar\\.(gz|xz|bz2)" file;
        in
        if archive == null then null else builtins.head archive;
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
    "3.12" = {
      constructor = tvp.builder;
      builder = ./native/build-3.12.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://mirrors.kernel.org/gnu/diffutils/diffutils-${version}.tar.xz";
          inherit sha256;
        };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      helpers = { inherit tvp; };
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
          helperName = "pr";
          invocation = q: ''
            printf 'before\n' > before
            printf 'after\n' > after
            for mode in -l -ly; do
              rc=0
              ${q}/bin/diff "$mode" before after > paginated || rc=$?
              test "$rc" = 1
              grep -q before paginated
              grep -q after paginated
            done
          '';
        }
      );
    versionTable = versionTable // {
      "3.12" = versionTable."3.12" // {
        def = if native then ownedDefs."3.12" else versionTable."3.12".def;
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
