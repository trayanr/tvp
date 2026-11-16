{ tvp, ... }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build.nix;
        deps.perl = tvp.packages.perl_5;
        # Preserve the existing GCC15+ warning demotion; all other Werror stays.
        opts.compileFlags = [ "-Wno-error=unterminated-string-initialization" ];
      };
      releases."4.4.36" = "sha256-5eH0yu4KAd4q7ibjE4gH1tPKK45nKHlm0f79ZeH9iUM=";
    }
    {
      def = {
        builder = ./build.nix;
        deps.perl = tvp.packages.perl_5;
      };
      releases = {
        "4.5.0" = "sha256-gl52Tk/y5jBK24FM2ilwdLIi1UoE7b2OvHz1j8OvhX0=";
        "4.5.1" = "sha256-6bRqYjl8FTcpNfanXcOSnGIWHyYgvnt/V/A9aRAsGoY=";
        "4.5.2" = "sha256-cVE6McAaQovM1TZ6Mv2V8RXW2sUPtbYMd51ceUKuwHE=";
      };
    }
  ];
  packageMeta.upstream = {
    type = "git-tags";
    url = "https://github.com/besser82/libxcrypt";
    normalise =
      tag:
      let
        matched = builtins.match "v([0-9]+\\.[0-9]+\\.[0-9]+)" tag;
      in
      if matched == null then null else builtins.head matched;
  };
  pname = "libxcrypt";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable packageMeta;
    source =
      { version, sha256 }:
      import <nix/fetchurl.nix> {
        url = "https://github.com/besser82/libxcrypt/releases/download/v${version}/libxcrypt-${version}.tar.xz";
        inherit sha256;
      };
    tests = import ./tests/installed.nix;
    testDeps = {
      pkg-config = tvp.packages.pkg-config;
      baseline = tvp.lib.packages.withConstraint {
        category = "artifact";
        reason = "Historical libxcrypt 4.4.36 crypt-format ABI baseline, instantiated from the current family.";
      } (family.instantiate { version = "4.4.36"; });
    };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.libxcrypt = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
