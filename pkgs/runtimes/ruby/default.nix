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
        builder = ./owned/build-3.4.10.nix;
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
            patch
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
  ruby4Definition =
    (tvpLib.packages.mkDefs {
      "4.0.6" = {

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
        builder = ./owned/build-4.0.6.nix;
        source =
          { version, sha256 }:
          import <nix/fetchurl.nix> {
            url = "https://cache.ruby-lang.org/pub/ruby/${pkgs.lib.versions.majorMinor version}/ruby-${version}.tar.gz";
            inherit sha256;
          };
        dependencyNames =
          specification:
          builtins.filter (
            name: name != "rustc" || (specification.tvp.jit.yjit || specification.tvp.jit.zjit)
          ) (builtins.attrNames ruby4Definition.deps);
        deps = {

          inherit (candidate.tools)
            bash
            coreutils
            gzip
            python
            binutils
            patchelf
            grep
            gawk
            diffutils
            findutils
            ;
          sed = candidate.tools.sed;
          patch = candidate.tools.patch;
          gnumake = candidate.tools.make;
          gnutar = candidate.tools.tar;
          inherit (tvp.packages) openssl libyaml;
          zlib = tvp.packages.zlib_1;
          libffi = tvp.packages.libffi_3;
          # Explicit precompiled Rust boundary, build-only for YJIT/ZJIT. No source bootstrap.
          rustc = tvp.packages.rustc_1;
        };
      };
    })."4.0.6";
  # Keep each accepted definition's libraries, options, patches, status and base.
  # Only construction protocol/tools change; no dependency API line is promoted.
  ownedDefinition =
    old:
    old
    // {
      constructor = tvp.builder;
      builder = ./owned + "/${builtins.baseNameOf old.builder}";
      helpers = {
        inherit tvp;
      };
      testContext =
        package:
        tvpLib.tests.fromPackage {
          builder = tvp.builder;
          inherit package;
        };
      dependencyNames =
        specification:
        builtins.filter (
          name:
          name != "rustc" || (specification.tvp.jit.yjit or false) || (specification.tvp.jit.zjit or false)
        ) (builtins.attrNames specification.dependencyProviders);
      deps = (builtins.removeAttrs old.deps [ "gnused" ]) // {
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
          patch
          ;
        gnumake = candidate.tools.make;
        gnutar = candidate.tools.tar;
      };
    };
  versionTable = builtins.mapAttrs (
    version: entry:
    entry
    // {
      def =
        if !native then
          entry.def
        else if version == "3.4.10" then
          definition
        else if version == "4.0.6" then
          ruby4Definition
        else
          ownedDefinition entry.def;
    }
  ) retained.versionTable;
  publicArgs = retained // {
    inherit versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      if package ? testContext then
        (import ./tests {
          inherit pkgs tvpLib;
          ruby = package;
          inherit (package.tvp.declaredTestDependencies) consumerCompiler;
        })
        // pkgs.lib.optionalAttrs (package.version == "3.4.10" || package.version == "4.0.6") (
          import (if package.version == "4.0.6" then ./tests/native-4.nix else ./tests/native.nix) {
            inherit
              pkgs
              tvp
              tvpLib
              package
              ;
          }
        )
        // (import ./tests/upstream.nix { inherit tvp package; })
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
  variants = previous.variants // {
    build-steps =
      previous.variants.build-steps
      // pkgs.lib.optionalAttrs native {
        ruby_4_0_6 = tvp.builder {
          recipe = import ./owned/build-4.0.6.nix;
          args = {
            inherit tvp;
            inherit (pkgs) lib;
            base = retained.versionTable."4.0.6".def.base;
            version = "4.0.6";
            src = canonical.ruby_4_0_6.src;
          } // (ownedDefinition retained.versionTable."4.0.6".def).deps;
          dependencyNames = ruby4Definition.dependencyNames;
          infrastructure = retained.infra;
          metadata = {
            status = previous.variants.build-steps.ruby_4_0_6.tvp.status;
            canonical = false;
            variant = "build-steps";
            builder = "build-4.0.6.nix";
            definition = "4.0.6";
            declaredTestDependencies = canonical.ruby_4_0_6.tvp.declaredTestDependencies;
          };
          selection = {
            namespace = "variants.build-steps";
            selector = "ruby_4_0_6";
            kind = "variant";
            pname = "ruby";
            version = "4.0.6";
            canonical = "ruby_4_0_6";
          };
          testContext =
            package:
            tvpLib.tests.fromPackage {
              builder = tvp.builder;
              inherit package;
            };
          mkTests = package: publicArgs.extraArgs.mkTests package;
        };
      };
  };
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
