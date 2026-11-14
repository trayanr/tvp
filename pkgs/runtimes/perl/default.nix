{ pkgs, tvp }:
let
  retained = import ./retained-construction.nix { inherit pkgs tvp; };
  pname = "perl";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-owned-5.24.4.nix;
        base = tvp.baseTiers.full;
        opts.cStandard = "gnu17";
        opts.upstreamNonpasses = [ "Time-Local-rolling-century-1970" ];
        deps = { };
        patches = [
          {
            file = ./patches/configure-gcc-major.patch;
            reason = "Limit all GCC 1 probes to that major: preserve modern aliasing safety, preprocessor selection and the structure-return ABI.";
          }
          {
            file = ./patches/linux-elf-probe.patch;
            reason = "The Linux ELF probe uses implicit-int main, rejected by modern GCC even in GNU17, and wrongly selects the obsolete a.out shared-library format. Give the probe its actual int return type.";
          }
        ];
      };
      releases = {
        "5.24.4" = "sha256-vy893bEBVNgzzbQVqT8WcrbYWZ6HkTtmwIXDMss2GXA=";
      };
    }
    {
      def = {
        builder = ./build-owned-5.24.4.nix;
        base = tvp.baseTiers.full;
        opts.cStandard = "gnu17";
        opts.upstreamNonpasses = [ "Time-Local-rolling-century-1970" ];
        deps = { };
        patches = [
          {
            file = ./patches/configure-gcc-major.patch;
            reason = "Limit all GCC 1 probes to that major: preserve modern aliasing safety, preprocessor selection and the structure-return ABI.";
          }
        ];
      };
      releases = {
        "5.28.3" = "sha256-r8nB1mFZeuFNnog8UHEJK+1z9gwxCbKUgj6gGspwURQ=";
      };
    }
    {
      def = {
        builder = ./build-owned-5.30.3.nix;
        base = tvp.baseTiers.full;
        opts.cStandard = "gnu17";
        deps = { };
      };
      releases = {
        "5.30.3" = "sha256-MuBMi7exrssnQqf3rA6rrBAPOCRzUqc61/oQTjnnQG8=";
        "5.32.1" = "sha256-A7aTkBzYroByMbF4d5jPHy4LilYhjQe32kT3hKfK6yw=";
        "5.34.3" = "sha256-WxL2KGMzKypfVBAq+c34wBCHfkvzKUkR7b1ZSyoejt4=";
      };
    }
    {
      def = {
        builder = ./build-owned-5.36.3.nix;
        base = tvp.baseTiers.full;
        deps = { };
      };
      releases = {
        "5.36.3" = "sha256-8qGtiBFjkaF2Ji3ULfxS7yKvtA9MDpgQ8V1WHm8ccmo=";
        "5.38.5" = "sha256-t2Z9P/MJBohSr3hTkQqszsJsg51xdAISG2ZKxwXge/4=";
        "5.40.5" = "sha256-Cdkmri0bJ3w7zmIFTEHaR8mBOA1xnEHPmAtnlFzFge0=";
        "5.42.3" = "sha256-ETd0CYWDe1zfFfDPq5Miedy0NS+RL+1vwUTotPCCNic=";
      };
    }
    {
      def = {
        builder = ./build-owned-5.44.0.nix;
        base = tvp.baseTiers.full;
        source =
          { version, sha256 }:
          import <nix/fetchurl.nix> {
            url = "https://www.cpan.org/src/5.0/perl-${version}.tar.gz";
            inherit sha256;
          };
        deps = { };
      };
      releases = {
        "5.44.0" = "sha256-O4VQZrkkkctA6Gr/scpX0aOIqkPlG5HHgGoywvZflsM=";
      };
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    packageMeta = retained.packageMeta or { };
    source =
      { version, sha256 }:
      pkgs.fetchurl {
        urls = [
          "https://www.cpan.org/src/5.0/perl-${version}.tar.gz"
          "https://cpan.metacpan.org/src/5.0/perl-${version}.tar.gz"
        ];
        inherit sha256;
      };
    tests = import ./tests/installed.nix;
  };
  recipe = family // {
    extraArgs = family.extraArgs // {
      mkTests = import ./tests/caller-factory.nix {
        inherit retained;
        inherit (pkgs) lib;
        tests = import ./tests/installed.nix;
      };
    };
  };
  canonical = tvp.lib.packages.mkVersions recipe;
in
{
  recipes.perl = recipe // {
    constructionRecipe = retained;
  };
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
