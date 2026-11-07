{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "1.32" = {
      builder = ./build-1.32.nix;
      base = tvp.bases.default;
      deps = {
        acl = (
          tvp.lib.packages.withConstraint {
            reason = "tar xattrs.c defines static acl_*_at helpers with three arguments; ACL 2.4 introduces public four-argument functions of the same names. Native tar 1.32 and 1.35 fail with ACL 2.4.0; use the working 2.3 line.";
          } tvp.packages.acl_2_3
        );
        attr = tvp.packages.attr_2;
      };
    };
    "1.35" = {
      builder = ./build-1.35.nix;
      base = tvp.bases.default;
      deps = {
        acl = (
          tvp.lib.packages.withConstraint {
            reason = "tar xattrs.c defines static acl_*_at helpers with three arguments; ACL 2.4 introduces public four-argument functions of the same names. Native tar 1.32 and 1.35 fail with ACL 2.4.0; use the working 2.3 line.";
          } tvp.packages.acl_2_3
        );
        attr = tvp.packages.attr_2;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.32";
      releases."1.32" = "sha256-0NOuB/EDMjvoCbw+rA3MOG1SxSYkmf4FURrEeIrx/dg=";
      releases."1.33" = "sha256-Zqg0Sx3IOkEdMRvRVH4BduVswxHyjulKMPhNr7PZBn4=";
      releases."1.34" = "sha256-Y769JoecXh7qQ1Lw0DyZH5Zq6z3es8dEXJAlaNVBHSg=";
    }
    {
      def = defs."1.35";
      releases."1.35" = "sha256-TWL/NzQux67XSFNTI5MMfPlKz3HDWRiCsmp+pQ8+3BY=";
    }
  ];
  pname = "gnutar";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    packageMeta.upstream = import ./upstream.nix;
    extraArgs.mkTests =
      package:
      import ./tests {
        inherit pkgs tvpLib package;
        helpers = [
          {
            bin = "gzip";
            package = tvp.packages.gzip;
            flag = "-z";
          }
          {
            bin = "bzip2";
            package = tvp.packages.bzip2_1;
            flag = "-j";
          }
          {
            bin = "xz";
            package = tvp.packages.xz_5;
            flag = "-J";
          }
          {
            bin = "zstd";
            package = tvp.packages.zstd_1;
            flag = "--zstd";
          }
        ];
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
    "1.35" = {
      constructor = tvp.builder;
      builder = ./native/build-1.35.nix;
      base = candidate.base;
      source =
        { version, sha256 }:
        import <nix/fetchurl.nix> {
          url = "https://mirrors.kernel.org/gnu/tar/tar-${version}.tar.xz";
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
        coreutils = constructionTool "coreutils";
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
        acl = defs."1.35".deps.acl;
        attr = tvp.packages.attr_2;
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
            helpers = [
              {
                bin = "gzip";
                package = tvp.packages.gzip;
                flag = "-z";
              }
              {
                bin = "bzip2";
                package = tvp.packages.bzip2_1;
                flag = "-j";
              }
              {
                bin = "xz";
                package = tvp.packages.xz_5;
                flag = "-J";
              }
              {
                bin = "zstd";
                package = tvp.packages.zstd_1;
                flag = "--zstd";
              }
            ];
          }
        else
          packageArgs.extraArgs.mkTests package
      )
      // pkgs.lib.optionalAttrs (package ? testContext) (
        import ../../../lib/tests/command-source-edit.nix { inherit tvp package; }
      );
    versionTable = versionTable // {
      "1.35" = versionTable."1.35" // {
        def = if native then ownedDefs."1.35" else versionTable."1.35".def;
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
