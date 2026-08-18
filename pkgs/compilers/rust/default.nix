{ pkgs, tvp }:
let
  tvpLib = tvp.lib;

  defs = {
    "1.97.1" = {
      builder = ./build-1.97.nix;
      base = tvp.bases.gcc13;
      deps = { };
      blob = {
        reason = "Upstream's binary distribution. rustc is self-hosting and TVP has no Rust chain, so there is nothing in the catalogue that could compile it.";
        needs = "A from-source chain: mrustc (C++, reaches ~1.54) and then a walk forward, or a period rustc able to build this one. Until then this package exists only for the platforms upstream publishes a binary for, which is what bounds the architectures TVP can serve.";
      };
    };
  };

  versionTable = tvpLib.packages.mkTable (import ./1.nix { inherit defs; });

  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs)
        lib
        fetchurl
        autoPatchelfHook
        zlib
        ;
    };
    pname = "rustc";
    inherit versionTable;

    extraArgs = {
      mkTests =
        rustc:
        import ./tests {
          inherit pkgs tvpLib rustc;
        };
    };

    packageMeta = {
      upstream = {
        # static.rust-lang.org/dist/ is an S3 bucket with no listing (416), so
        # releases are read from the repository's tags instead.
        type = "git-tags";
        url = "https://github.com/rust-lang/rust";

        normalise = tag: tag;

        include = version: builtins.match "[0-9]+\\.[0-9]+\\.[0-9]+" version != null;
      };
    };
  };

  aliases = {
    rustc_1 = canonical.rustc_1_97_1;
    rustc = canonical.rustc_1_97_1;
  };
in
canonical // tvpLib.packages.checkAliases { inherit canonical aliases; }
