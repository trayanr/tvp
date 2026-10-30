# These checks belong to this base's declared assembly, rather than to the
# generic ownership capability shared with other bases.
{
  pkgs,
  tvpLib,
  base,
}:
{
  linker-metadata = tvpLib.bases.mkBaseTest {
    inherit base;
    name = "linker-metadata";
    script = ''
      support=${base.stdenv.cc.bintools}/nix-support
      test "$(cat "$support/orig-libc")" = '${base.stdenv.cc.libc}'
      cat "$support/dynamic-linker"
    '';
    expected = "${base.stdenv.cc.libc}/${base.platform.dynamicLinker}";
  };
  bootstrap-build-tools = tvpLib.tests.mkBatch {
    inherit pkgs;
    name = "base-${base.name}-bootstrap-build-tools";
    suite = pkgs.lib.concatMapAttrs (
      name: tool:
      if (tool.tvp.variant or null) != "gcc13" || tool.tvp.base != "gcc13" then
        throw "TVP: ${base.name} bootstrap tool '${name}' must be a package-owned gcc13 variant."
      else
        pkgs.lib.mapAttrs' (test: drv: pkgs.lib.nameValuePair "${name}-${test}" drv) tool.tests
    ) base.bootstrap.buildTools;
  };
  autotools = tvpLib.tests.mkBatch {
    inherit pkgs;
    name = "base-${base.name}-autotools";
    suite = base.autotoolsValidation.tests;
  };
  autotools-runtime-ownership = tvpLib.bases.mkOwnershipTest {
    inherit pkgs base;
    name = "autotools-runtime-ownership";
    roots = base.autotoolsValidation.runtimePaths;
    allowedRuntimePaths =
      base.ownership.allowedRuntimePaths
      ++ base.buildToolValidation.canonicalToolRuntimePaths
      ++ base.buildToolValidation.runtimePaths
      ++ base.autotoolsValidation.runtimePaths;
  };
  build-tools = tvpLib.tests.mkBatch {
    inherit pkgs;
    name = "base-${base.name}-build-tools";
    suite = base.buildToolValidation.tests;
  };
  build-tool-consumers = tvpLib.tests.mkBatch {
    inherit pkgs;
    name = "base-${base.name}-build-tool-consumers";
    suite = base.buildToolValidation.consumerTests;
  };
  build-tool-runtime-ownership = tvpLib.bases.mkOwnershipTest {
    inherit pkgs base;
    name = "build-tool-runtime-ownership";
    roots = base.buildToolValidation.runtimePaths;
    allowedRuntimePaths =
      base.ownership.allowedRuntimePaths
      ++ base.buildToolValidation.canonicalToolRuntimePaths
      ++ base.buildToolValidation.runtimePaths;
  };
  gprofng = tvpLib.bases.mkBaseTest {
    inherit base;
    name = "gprofng";
    script = ''
      gprofng display html --help > frontend-help
      gp-display-html --help > direct-help
      grep -Fq 'Usage: gprofng display html' frontend-help
      grep -Fq 'Usage: gprofng display html' direct-help
      echo ok
    '';
    expected = "ok";
  };
  consumers = tvpLib.tests.mkBatch {
    inherit pkgs;
    name = "base-${base.name}-consumers";
    suite = base.consumerTests;
  };
  consumer-runtime-ownership = tvpLib.bases.mkOwnershipTest {
    inherit pkgs base;
    name = "consumer-runtime-ownership";
    roots = pkgs.lib.attrValues base.consumerPackages;
    allowedRuntimePaths =
      base.ownership.allowedRuntimePaths
      ++ pkgs.lib.attrValues base.consumerPackages;
  };
  components = tvpLib.tests.mkBatch {
    inherit pkgs;
    name = "base-${base.name}-components";
    suite =
      let
        c = base.components;
        packages = {
          inherit (c)
            gcc
            binutils
            libc
            perl
            ;
        } // c.floor // c.libraries;
      in
      pkgs.lib.concatMapAttrs (
        name: package:
        pkgs.lib.mapAttrs' (test: drv: pkgs.lib.nameValuePair "${name}-${test}" drv) package.tests
      ) packages;
  };
}
