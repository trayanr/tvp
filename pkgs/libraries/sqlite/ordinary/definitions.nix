# Native definition data. Every selected procedure remains complete and independent.
{
  pkgs,
  tvp,
  tvpLib,
  candidate,
  constructionTool,
  defs,
}:
let
  migrated = pkgs.lib.mapAttrs (_: definition: {
    name = definition.name;
    constructor = tvp.builder;
    builder =
      if definition.builder == ../build-3.48.0.nix then ./build-3.48.0.nix else ./build-3.0.0.nix;
    base = candidate.base;
    source = import ./source.nix { inherit (pkgs) fetchurl; };
    testContext =
      package:
      tvpLib.tests.fromPackage {
        builder = tvp.builder;
        inherit package;
      };
    helpers = {
      inherit tvp;
    };
    opts =
      (definition.opts or { })
      // pkgs.lib.optionalAttrs (pkgs.lib.versionOlder definition.name "3.6.10") {
        # 3.6.10 replaced Tcl_Interp.result access with public result functions.
        # Tcl8 retains that ABI behind this compatibility macro.
        compileFlags =
          (definition.opts.compileFlags or [ ])
          ++ [ "-DUSE_INTERP_RESULT" ]
          ++ pkgs.lib.optional (pkgs.lib.versionOlder definition.name "3.5.6") "-fcommon";
      };
    patches = definition.patches or [ ];
    deps = {
      bash = constructionTool "bash";
      coreutils = constructionTool "coreutils";
      pkgConfig = constructionTool "pkgConfig";
      gnumake = constructionTool "make";
      gnutar = constructionTool "tar";
      gzip = constructionTool "gzip";
      findutils = constructionTool "findutils";
      sed = constructionTool "sed";
      grep = constructionTool "grep";
      gawk = constructionTool "gawk";
      diffutils = constructionTool "diffutils";
      patch = constructionTool "patch";
      python = constructionTool "python";
      binutils = constructionTool "binutils";
      patchelf = constructionTool "patchelf";
      tcl = tvp.packages.tcl_8;
      readline = tvp.packages.readline_8;
      testZlib = tvp.packages.zlib_1;
    };
  }) defs;
  # 3.5.6 removes the test header's tentative pager global. This boundary
  # splits native options only; the retained version table remains untouched.
  afterCommonGlobal = tvpLib.packages.mkDefs {
    "3.5.6" = {
      constructor = tvp.builder;
      builder = ./build-3.0.0.nix;
      base = candidate.base;
      source = import ./source.nix { inherit (pkgs) fetchurl; };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      helpers = {
        inherit tvp;
      };
      opts = {
        compileFlags = [
          "-std=gnu17"
          "-DUSE_INTERP_RESULT"
        ];
        configureIsExecutable = false;
        hardeningDisable = [ "format" ];
        pkgConfigMajorMinor = true;
      };
      patches = [ ];
      deps = {
        bash = constructionTool "bash";
        coreutils = constructionTool "coreutils";
        pkgConfig = constructionTool "pkgConfig";
        gnumake = constructionTool "make";
        gnutar = constructionTool "tar";
        gzip = constructionTool "gzip";
        findutils = constructionTool "findutils";
        sed = constructionTool "sed";
        grep = constructionTool "grep";
        gawk = constructionTool "gawk";
        diffutils = constructionTool "diffutils";
        patch = constructionTool "patch";
        python = constructionTool "python";
        binutils = constructionTool "binutils";
        patchelf = constructionTool "patchelf";
        tcl = tvp.packages.tcl_8;
        readline = tvp.packages.readline_8;
        testZlib = tvp.packages.zlib_1;
      };
    };
  };
in
migrated // afterCommonGlobal
