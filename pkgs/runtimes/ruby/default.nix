{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  previous = import ./legacy.nix { inherit pkgs tvp; };
  retained = previous.recipes.ruby;
  candidate = import ../../../bases/source-gnu { };
  native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  definition =
    (tvpLib.packages.mkDefs {
      "3.4.10" = {

        constructor = tvp.builder;
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
        builder = ./native/build-3.4.10.nix;
        source =
          { version, sha256 }:
          import <nix/fetchurl.nix> {
            url = "https://cache.ruby-lang.org/pub/ruby/${pkgs.lib.versions.majorMinor version}/ruby-${version}.tar.gz";
            inherit sha256;
          };
        dependencyNames =
          specification:
          builtins.filter (name: name != "rustc" || specification.tvp.jit.yjit) (
            builtins.attrNames definition.deps
          );
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
            ;
          gnumake = candidate.tools.make;
          gnutar = candidate.tools.tar;
          inherit (tvp.packages) openssl libyaml;
          zlib = tvp.packages.zlib_1;
          libffi = tvp.packages.libffi_3;
          # Explicit precompiled Rust boundary, build-only for YJIT. No source bootstrap.
          rustc = tvp.packages.rustc_1;
        };
      };
    })."3.4.10";
  versionTable = retained.versionTable // {
    "3.4.10" = retained.versionTable."3.4.10" // {
      def = if native then definition else retained.versionTable."3.4.10".def;
    };
  };
  publicArgs = retained // {
    inherit versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        import ./tests/native.nix {
          inherit
            pkgs
            tvp
            tvpLib
            package
            ;
        }
      else
        (retained.extraArgs.mkTests.override { inherit pkgs; }) package
    ) { inherit pkgs; };
  };
  canonical = tvpLib.packages.mkVersions publicArgs;
  pname = "ruby";
in
{
  recipes.${pname} = publicArgs // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (previous) variants;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
